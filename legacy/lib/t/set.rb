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

    desc "language LANGUAGE_NAME", "Selects the language you'd like to receive notifications in."
    def language(language_name)
      x_settings(lang: language_name)
      say "@#{@rcfile.active_profile[0]}'s language has been updated."
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

    desc "profile_background_image FILE", "Sets the background image on your Twitter profile."
    method_option "tile", aliases: "-t", type: :boolean, desc: "Whether or not to tile the background image."
    def profile_background_image(file)
      x_update_profile_background_image(File.new(File.expand_path(file)), tile: options["tile"], skip_status: true)
      say "@#{@rcfile.active_profile[0]}'s background image has been updated."
    end
    map %w[background background_image] => :profile_background_image

    desc "profile_image FILE", "Sets the image on your Twitter profile."
    def profile_image(file)
      x_update_profile_image(File.new(File.expand_path(file)))
      say "@#{@rcfile.active_profile[0]}'s image has been updated."
    end
    map %w[avatar image] => :profile_image

    desc "website URI", "Sets the website field on your profile."
    def website(uri)
      x_update_profile(url: uri)
      say "@#{@rcfile.active_profile[0]}'s website has been updated."
    end
  end
end
