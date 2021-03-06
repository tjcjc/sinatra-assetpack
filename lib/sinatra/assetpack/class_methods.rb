module Sinatra
  module AssetPack
    # Class methods that will be given to the Sinatra application.
    module ClassMethods
      # Sets asset options, or gets them
      def assets(&blk)
        @options ||= Options.new(self, &blk)
        self.assets_initialize!  if block_given?

        @options
      end

      def assets_initialize!
        add_compressed_routes!
        add_individual_routes!
      end

      # Add routes for the compressed versions
      def add_compressed_routes!
        assets.packages.each do |name, package|
          get package.route_regex do
            content_type package.type
            last_modified package.mtime  if package.mtime

            settings.assets.cache[package.hash] ||= package.minify
          end
        end
      end

      # Add the routes for the individual files.
      def add_individual_routes!
        assets.served.each do |path, from|
          get "/#{path}/*".squeeze('/') do |file|
            fmt = File.extname(file)[1..-1]

            # Sanity checks
            pass unless AssetPack.supported_formats.include?(fmt)
            fn = asset_path_for(file, from)  or pass

            # Send headers
            content_type fmt.to_sym
            last_modified File.mtime(fn).to_i
            expires 86400*30, :public

            format = File.extname(fn)[1..-1]

            if AssetPack.supported_formats.include?(format)
              # It's a raw file, just send it
              not_found  unless format == fmt

              if fmt == 'css'
                asset_filter_css File.read(fn)
              else
                send_file fn
              end
            else
              # Dynamic file
              not_found unless AssetPack.tilt_formats[format] == fmt
              out = render format.to_sym, File.read(fn)
              out = asset_filter_css(out)  if fmt == 'css'
              out
            end
          end
        end

      end
    end
  end
end
