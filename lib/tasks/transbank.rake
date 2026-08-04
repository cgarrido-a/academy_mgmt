require 'ostruct'

namespace :transbank do
  desc 'Busca cobros de Webpay que quedaron sin matrícula (últimos 7 días). Uso: rake transbank:audit'
  task audit: :environment do
    # OJO: la API de Transbank sólo responde el estado de una transacción hasta 7 días
    # después. Más atrás que eso hay que mirar el Portal de Pagos a mano.
    sospechosas = TransbankTransaction
                  .where(status: %w[pending failed authorized_error])
                  .where('created_at > ?', 7.days.ago)
                  .where.not(token: nil)
                  .order(:id)

    puts "Revisando #{sospechosas.count} transacción(es) no autorizadas de los últimos 7 días..."
    puts

    tx = Transbank::Webpay::WebpayPlus::Transaction.new(
      OpenStruct.new(
        commerce_code: TransbankConfig.commerce_code,
        api_key: TransbankConfig.api_key,
        environment: TransbankConfig.environment,
        timeout: 15_000
      )
    )

    cobradas = []

    sospechosas.each do |t|
      estado = begin
        tx.status(t.token)
      rescue StandardError => e
        puts "    tx #{t.id}: no se pudo consultar (#{e.message.to_s[0, 80]})"
        next
      end

      cobrada = estado['status'] == 'AUTHORIZED' || estado['response_code']&.zero?
      unless cobrada
        puts "    tx #{t.id}: BD=#{t.status} Transbank=#{estado['status']} → sin cobro"
        next
      end

      pago = Payment.find_by(reference_number: estado['authorization_code'].to_s)
      if pago.present?
        puts "    tx #{t.id}: cobrada y con Payment ##{pago.id} (revisar el estado de la transacción)"
        next
      end

      cobradas << [t, estado]
      puts "*** tx #{t.id}: COBRADA SIN MATRÍCULA | $#{t.amount.to_i} | " \
           "auth=#{estado['authorization_code']} | #{t.created_at.in_time_zone('America/Santiago').strftime('%d-%m-%Y %H:%M')}"
    end

    puts
    if cobradas.empty?
      puts '✓ Sin cobros perdidos.'
    else
      puts "⚠️  #{cobradas.size} cobro(s) sin matrícula. Para cada uno:"
      cobradas.each do |t, estado|
        puts "   - tx #{t.id} (#{t.buy_order}): /admin/transbank_transactions/#{t.id} → botón Reprocesar"
        puts "     rake \"transbank:reprocess[#{t.id}]\"  (guarda la respuesta y crea la matrícula)"
        puts "     auth=#{estado['authorization_code']} monto=$#{t.amount.to_i}"
      end
      abort 'Auditoría con hallazgos.'
    end
  end

  desc 'Crea la matrícula de un cobro que Transbank capturó. Uso: rake "transbank:reprocess[140]"'
  task :reprocess, [:id] => :environment do |_t, args|
    abort 'Falta el id de la transacción. Uso: rake "transbank:reprocess[140]"' if args[:id].blank?

    transaction = TransbankTransaction.find(args[:id])

    # Si no tenemos la respuesta guardada (transacciones viejas), se la pedimos a Transbank.
    if transaction.raw_response.blank?
      puts 'La transacción no tiene la respuesta guardada; consultando a Transbank...'
      tx = Transbank::Webpay::WebpayPlus::Transaction.new(
        OpenStruct.new(
          commerce_code: TransbankConfig.commerce_code,
          api_key: TransbankConfig.api_key,
          environment: TransbankConfig.environment,
          timeout: 15_000
        )
      )
      estado = tx.status(transaction.token)
      abort "Transbank dice que esta transacción está #{estado['status']}: no corresponde crear matrícula." unless
        estado['status'] == 'AUTHORIZED' || estado['response_code']&.zero?

      transaction.update_columns(raw_response: estado.to_json)
    end

    pagos = Array(transaction.reprocess!)
    transaction.reload

    puts "✓ Transacción #{transaction.id} → #{transaction.status}"
    pagos.each do |pago|
      enr = pago.enrollment
      puts "  Payment ##{pago.id} $#{pago.amount.to_i} (#{pago.payment_date}) → matrícula ##{enr.id}, " \
           "#{enr.enrollment_sections.count} clases"
    end
    puts "  Nota: #{transaction.error_message}" if transaction.error_message.present?
    puts '  El correo de confirmación NO se envía desde acá; mándalo aparte si corresponde.'
  rescue StandardError => e
    abort "✖ No se pudo reprocesar: #{e.message}"
  end
end
