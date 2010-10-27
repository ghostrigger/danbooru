require "danbooru_image_resizer/danbooru_image_resizer"
require "tmpdir"

class Upload < ActiveRecord::Base
  class Error < Exception ; end
  
  attr_accessor :file, :image_width, :image_height, :file_ext, :md5, :file_size
  belongs_to :uploader, :class_name => "User"
  belongs_to :post
  before_validation :initialize_uploader, :on => :create
  before_validation :initialize_status, :on => :create
  before_create :convert_cgi_file
  after_destroy :delete_temp_file
  validate :uploader_is_not_limited
  
  module ValidationMethods
    def uploader_is_not_limited
      if !uploader.can_upload?
        update_attribute(:status, "error: uploader has reached their daily limit")
      end
    end

    # Because uploads are processed serially, there's no race condition here.
    def validate_md5_uniqueness
      md5_post = Post.find_by_md5(md5)
      merge_tags(md5_post) if md5_post
    end
    
    def validate_file_exists
      unless File.exists?(file_path)
        update_attribute(:status, "error: file does not exist")
      end
    end
    
    def validate_file_content_type
      unless is_valid_content_type?
        update_attribute(:status, "error: invalid content type (#{file_ext} not allowed)")
      end
    end
    
    def validate_md5_confirmation
      if !md5_confirmation.blank? && md5_confirmation != md5
        update_attribute(:status, "error: md5 mismatch")
      end
    end
  end
  
  module ConversionMethods
    def process!
      CurrentUser.scoped(uploader, uploader_ip_addr) do
        update_attribute(:status, "processing")
        if is_downloadable?
          download_from_source(temp_file_path)
        end
        validate_file_exists
        self.file_ext = content_type_to_file_ext(content_type)
        validate_file_content_type
        calculate_hash(file_path)
        validate_md5_uniqueness
        validate_md5_confirmation
        calculate_file_size(file_path)
        calculate_dimensions(file_path) if has_dimensions?
        generate_resizes(file_path)
        move_file
        post = convert_to_post
        if post.save
          update_attributes(:status => "completed", :post_id => post.id)
        else
          update_attribute(:status, "error: " + post.errors.full_messages.join(", "))
        end
      end
    rescue Exception => x
      update_attribute(:status, "error: #{x} - #{x.message}")
    ensure
      delete_temp_file
    end

    def convert_to_post
      Post.new.tap do |p|
        p.tag_string = tag_string
        p.md5 = md5
        p.file_ext = file_ext
        p.image_width = image_width
        p.image_height = image_height
        p.rating = rating
        p.source = source
        p.file_size = file_size

        unless uploader.is_contributor?
          p.is_pending = true
        end
      end
    end
    
    def merge_tags(post)
      post.tag_string += " #{tag_string}"
      post.updater_id = uploader_id
      post.updater_ip_addr = uploader_ip_addr
      post.save
      update_attribute(:status, "duplicate: #{post.id}")
      raise
    end
  end
  
  module FileMethods
    def delete_temp_file
      FileUtils.rm_f(temp_file_path)
    end
    
    def move_file
      FileUtils.mv(file_path, md5_file_path)
    end

    def calculate_file_size(source_path)
      self.file_size = File.size(source_path)
    end

    # Calculates the MD5 based on whatever is in temp_file_path
    def calculate_hash(source_path)
      self.md5 = Digest::MD5.file(source_path).hexdigest
    end
  end

  module ResizerMethods
    def generate_resizes(source_path)
      generate_resize_for(Danbooru.config.small_image_width, Danbooru.config.small_image_width, source_path)
      generate_resize_for(Danbooru.config.medium_image_width, nil, source_path)
      generate_resize_for(Danbooru.config.large_image_width, nil, source_path)
    end

    def generate_resize_for(width, height, source_path)
      return if width.nil?
      return unless image_width > width
      return unless height.nil? || image_height > height

      unless File.exists?(source_path)
        raise Error.new("file not found")
      end

      size = Danbooru.reduce_to({:width => image_width, :height => image_height}, {:width => width, :height => height})

      # If we're not reducing the resolution, only reencode if the source image larger than
      # 200 kilobytes.
      if size[:width] == image_width && size[:height] == image_height && File.size?(source_path) < 200.kilobytes
        return
      end

      Danbooru.resize(file_ext, source_path, resized_file_path_for(width), size, 90)
    end
  end

  module DimensionMethods
    # Figures out the dimensions of the image.
    def calculate_dimensions(file_path)
      image_size = ImageSize.new(File.open(file_path, "rb"))
      self.image_width = image_size.get_width
      self.image_height = image_size.get_height
    end

    # Does this file have image dimensions?
    def has_dimensions?
      %w(jpg gif png swf).include?(file_ext)
    end
  end
  
  module ContentTypeMethods
    def is_valid_content_type?
      file_ext =~ /jpg|gif|png|swf/
    end
    
    def content_type_to_file_ext(content_type)
      case content_type
      when "image/jpeg"
        "jpg"
        
      when "image/gif"
        "gif"
        
      when "image/png"
        "png"
        
      when "application/x-shockwave-flash"
        "swf"
        
      else
        "bin"
      end
    end
    
    # Converts a content type string to a file extension
    def file_ext_to_content_type(file_ext)
      case file_ext
      when /\.jpeg$|\.jpg$/
        "image/jpeg"

      when /\.gif$/
        "image/gif"

      when /\.png$/
        "image/png"

      when /\.swf$/
        "application/x-shockwave-flash"

      else
        "application/octet-stream"
      end
    end
  end

  module FilePathMethods
    def md5_file_path
      prefix = Rails.env == "test" ? "test." : ""
      "#{Rails.root}/public/data/original/#{prefix}#{md5}.#{file_ext}"
    end
    
    def resized_file_path_for(width)
      prefix = Rails.env == "test" ? "test." : ""

      case width
      when Danbooru.config.small_image_width
        "#{Rails.root}/public/data/preview/#{prefix}#{md5}.jpg"

      when Danbooru.config.medium_image_width
        "#{Rails.root}/public/data/medium/#{prefix}#{md5}.jpg"

      when Danbooru.config.large_image_width
        "#{Rails.root}/public/data/large/#{prefix}#{md5}.jpg"
      end
    end
    
    def temp_file_path
      @temp_file_path ||= File.join(Rails.root, "tmp", "#{Time.now.to_f}.#{$PROCESS_ID}")
    end
  end
  
  module DownloaderMethods
    # Determines whether the source is downloadable
    def is_downloadable?
      source =~ /^http:\/\// && file_path.blank?
    end

    # Downloads the file to destination_path
    def download_from_source(destination_path)
      download = Download.new(source, destination_path)
      download.download!
      self.file_path = destination_path
      self.content_type = download.content_type || file_ext_to_content_type(source)
      self.file_ext = content_type_to_file_ext(content_type)
      self.source = download.source
    end
  end

  module CgiFileMethods
    def convert_cgi_file
      return if file.blank? || file.size == 0

      self.file_path = temp_file_path

      if file.local_path
        FileUtils.cp(file.local_path, file_path)
      else
        File.open(file_path, 'wb') do |out| 
          out.write(file.read)
        end
      end
      self.content_type = file.content_type || file_ext_to_content_type(file.original_filename)
      self.file_ext = content_type_to_file_ext(content_type)
    end
  end
  
  module StatusMethods
    def initialize_status
      self.status = "pending"
    end
    
    def is_pending?
      status == "pending"
    end
    
    def is_completed?
      status == "completed"
    end
  end
  
  module UploaderMethods
    def initialize_uploader
      self.uploader_id = CurrentUser.user.id
      self.uploader_ip_addr = CurrentUser.ip_addr
    end
  end
  
  include ConversionMethods
  include ValidationMethods
  include FileMethods
  include ResizerMethods
  include DimensionMethods
  include ContentTypeMethods
  include DownloaderMethods
  include FilePathMethods
  include CgiFileMethods
  include StatusMethods
  include UploaderMethods
  
  def presenter
    @presenter ||= UploadPresenter.new(self)
  end
end