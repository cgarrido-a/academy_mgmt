module Admin
  class ClassDiscountsController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_class_discount, only: [:edit, :update, :destroy]

    def index
      @class_discounts = ClassDiscount.order(number_of_classes: :asc)
    end

    def new
      @class_discount = ClassDiscount.new
    end

    def create
      @class_discount = ClassDiscount.new(class_discount_params)

      if @class_discount.save
        redirect_to admin_class_discounts_path, notice: 'Tramo de descuento creado exitosamente.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @class_discount.update(class_discount_params)
        redirect_to admin_class_discounts_path, notice: 'Tramo de descuento actualizado exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @class_discount.destroy
      redirect_to admin_class_discounts_path, notice: 'Tramo de descuento eliminado exitosamente.'
    end

    private

    def set_class_discount
      @class_discount = ClassDiscount.find(params[:id])
    end

    def class_discount_params
      params.require(:class_discount).permit(:number_of_classes, :discount_percentage)
    end
  end
end
