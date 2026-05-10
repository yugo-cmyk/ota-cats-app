class CatsController < ApplicationController
  before_action :set_cat, only: %i[ show edit update destroy ]

  # 【復活】大田区全体の地図ページ
  def map
    @cats = Cat.all
  end

  def index
    @cats = Cat.all
  end

  def show
  end

  def new
    @cat = Cat.new
  end

  def edit
  end

  def create
  @cat = Cat.new(cat_params)
  if @cat.save
    redirect_to @cat, notice: "登録に成功しました！"
  else
    # ↓ この一行が重要です！エラー内容をログに書き出します
    Rails.logger.error "【保存失敗の原因】: #{@cat.errors.full_messages.join(', ')}"
    render :new, status: :unprocessable_entity
  end

  def update
    if @cat.update(cat_params)
      redirect_to @cat, notice: "情報を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cat.destroy
    redirect_to cats_url, notice: "削除しました。"
  end

  private
    def set_cat
      @cat = Cat.find(params[:id])
    end

    def cat_params
      params.require(:cat).permit(:name, :description, :image, :latitude, :longitude, :ear_status)
    end
end