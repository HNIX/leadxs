module ThemeHelper
  def theme_options
    [
      [t("themes.system"), ""],
      [t("themes.light"), "light"],
      [t("themes.dark"), "dark"]
    ]
  end
  
  # Check if the current theme is dark mode
  # This is used for the formula editor to apply the appropriate CodeMirror theme
  def dark_mode?
    # First check user preference
    if user_signed_in? && current_user.respond_to?(:preferences)
      return current_user.preferences['theme'] == "dark"
    end
    
    # Then check session
    if session[:theme].present?
      return session[:theme] == "dark"
    end
    
    # Default to false (light mode)
    false
  end
end
