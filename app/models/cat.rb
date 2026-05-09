class Cat < ApplicationRecord
  has_one_attached :image
  before_save :process_image_and_gps

  private

  def process_image_and_gps
    # 手動ですでに緯度経度が入力されている場合は、自動取得より手動を優先する
    return if latitude.present? && longitude.present?

    return unless attachment_changes["image"]
    blob = attachment_changes["image"].attachable
    file_path = blob.try(:path) || blob.try(:tempfile)&.path
    return unless file_path && File.exist?(file_path)

    is_heic = File.extname(file_path).downcase =~ /\.heic|\.heif/
    working_path = file_path
    if is_heic
      temp_jpg = "/tmp/heic_tmp_#{SecureRandom.hex}.jpg"
      system("heif-convert #{file_path} #{temp_jpg}")
      working_path = temp_jpg if File.exist?(temp_jpg)
    end

    lat_raw = `identify -format '%[EXIF:GPSLatitude]' "#{working_path}"`.strip
    lng_raw = `identify -format '%[EXIF:GPSLongitude]' "#{working_path}"`.strip
    lat_ref = `identify -format '%[EXIF:GPSLatitudeRef]' "#{working_path}"`.strip
    lng_ref = `identify -format '%[EXIF:GPSLongitudeRef]' "#{working_path}"`.strip

    if lat_raw.present? && lng_raw.present?
      self.latitude = parse_exif_coordinate(lat_raw, lat_ref)
      self.longitude = parse_exif_coordinate(lng_raw, lng_ref)
    end

    File.delete(temp_jpg) if is_heic && File.exist?(temp_jpg)
  end

  def parse_exif_coordinate(coord_str, ref)
    parts = coord_str.to_s.split(',').map { |p| p.strip.split('/') }
    decimal_parts = parts.map { |p| p.size == 2 ? p[0].to_f / p[1].to_f : p[0].to_f }
    return nil if decimal_parts.size < 3
    res = decimal_parts[0] + (decimal_parts[1] / 60.0) + (decimal_parts[2] / 3600.0)
    (ref == "S" || ref == "W") ? -res : res
  end
end