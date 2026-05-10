class Cat < ApplicationRecord
  has_one_attached :image

  # 保存する前に、写真から位置情報を抜き出す処理（HEIC対応版）
  after_commit :process_image_and_gps, on: [:create, :update] #

  private

def process_image_and_gps
    # すでに緯度経度がある場合は何もしない
    return if latitude.present? && longitude.present?
    return unless image.attached?

    # --- 追記: 処理が始まったことを確認 ---
    Rails.logger.info "--- GPS抽出プロセスを開始します (ID: #{id}) ---"

    # 保存済みのファイルからGPSを抽出
    image.open do |file|
      img = MiniMagick::Image.open(file.path)

      # --- 追記: 写真からどんなデータが取れているか確認 ---
      Rails.logger.info "写真のEXIFキー: #{img.exif.keys.join(', ')}" if img.exif.present?
      
      lat_raw = img.exif['GPSLatitude']
      lng_raw = img.exif['GPSLongitude']
      lat_ref = img.exif['GPSLatitudeRef']
      lng_ref = img.exif['GPSLongitudeRef']

      if lat_raw.present? && lng_raw.present?
        lat = parse_exif_coordinate(lat_raw, lat_ref)
        lng = parse_exif_coordinate(lng_raw, lng_ref)

        # --- 追記: 計算結果を確認 ---
        Rails.logger.info "計算された座標: Lat #{lat}, Lng #{lng}"
        
        # データベースを直接更新（保存完了後なのでこれを使います）
        update_columns(latitude: lat, longitude: lng) if lat && lng
      else
        # --- 追記: GPSがなかった場合の報告 ---
        Rails.logger.warn "この写真にはGPSデータが見つかりませんでした。"
      end
    end
  rescue => e
    Rails.logger.error "GPS抽出プロセスでエラーが発生しました: #{e.message}"
  end

  # EXIFの度分秒形式を数値に変換するメソッド
  def parse_exif_coordinate(coord_str, ref)
    parts = coord_str.to_s.split(',').map { |p| p.strip.split('/') }
    decimal_parts = parts.map { |p| p.size == 2 ? p[0].to_f / p[1].to_f : p[0].to_f }
    return nil if decimal_parts.size < 3
    
    res = decimal_parts[0] + (decimal_parts[1] / 60.0) + (decimal_parts[2] / 3600.0)
    (ref == "S" || ref == "W") ? -res : res
  end
end