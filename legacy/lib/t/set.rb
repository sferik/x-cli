require "thor"
require "t/rcfile"
require "t/requestable"

module T
  class Set < Thor
    include T::Requestable

    check_unknown_options!

    def initialize(*)
      @rcfile = T::RCFile.instance
      super
    end

    desc "active SCREEN_NAME [CONSUMER_KEY]", "Set your active account."
    def active(screen_name, consumer_key = nil)
      screen_name = screen_name.tr("@", "")
      @rcfile.path = options["profile"] if options["profile"]
      consumer_key = @rcfile[screen_name].keys.last if consumer_key.nil?
      @rcfile.active_profile = {"username" => @rcfile[screen_name][consumer_key]["username"], "consumer_key" => consumer_key}
      say "Active account has been updated to #{@rcfile.active_profile[0]}."
    end
    map %w[account default] => :active

    desc "bio DESCRIPTION", "Edits your Bio information on your Twitter profile."
    def bio(description)
      x_update_profile(description:)
      say "@#{@rcfile.active_profile[0]}'s bio has been updated."
    end

    desc "location PLACE_NAME", "Updates the location field in your profile."
    def location(place_name)
      x_update_profile(location: place_name)
      say "@#{@rcfile.active_profile[0]}'s location has been updated."
    end

    desc "name NAME", "Sets the name field on your Twitter profile."
    def name(name)
      x_update_profile(name:)
      say "@#{@rcfile.active_profile[0]}'s name has been updated."
    end

    desc "profile_image FILE", "Sets the image on your Twitter profile."
    def profile_image(file)
      x_update_profile_image(File.new(File.expand_path(file)))
      say "@#{@rcfile.active_profile[0]}'s image has been updated."
    end
    map %w[avatar image] => :profile_image

    desc "profile_link_color COLOR_CODE", "Sets the color scheme of links on your profile page."
    def profile_link_color(color_code)
      x_update_profile(profile_link_color: color_code)
      say "@#{@rcfile.active_profile[0]}'s profile link color has been updated."
    end

    desc "website URI", "Sets the website field on your profile."
    def website(uri)
      x_update_profile(url: uri)
      say "@#{@rcfile.active_profile[0]}'s website has been updated."
    end
  end
end
