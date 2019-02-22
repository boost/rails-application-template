vcr = yes? 'Install VCR?'
foundation = yes? 'Install Foundation?'

# ______ GEMS WE LOVE _______

gem_group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'chromedriver-helper'
  gem 'factory_bot_rails'
  gem 'selenium-webdriver'
  gem 'site_prism'
  gem 'vcr' if vcr
  gem 'webmock' if vcr
end

gem_group :development, :test do
  gem 'pry-rails'
  gem 'rspec-rails', '~> 3.8'
end

if foundation
  gem 'sprockets-es6'
  gem 'jquery-rails', '~> 4.3', '>= 4.3.3'
  gem 'foundation-rails'
  gem 'autoprefixer-rails'
  gem 'sass-rails', '~> 5.0'
end

gem 'haml-rails'

# ______ Travis _______

file '.travis.yaml', <<-CODE
sudo: required

language: ruby

stages:
- lint
- test

addons:
  chrome: stable

cache: bundler

jobs:
include:
  - stage: lint
    script:
      - rubocop
  - stage: test
    script:
      - bundle exec rspec

CODE

# ______ The cop _______

file '.rubocop.yml', <<-CODE
AllCops:
  Exclude:
  - 'Gemfile'
  - 'bin/**/*'
  - 'config/**/*'
  - 'db/**/*'
  - 'spec/**/**/**/*'

Style/Documentation:
  Enabled: false

Metrics/LineLength:
  Max: 120

Metrics/AbcSize:
  Max: 20

CODE

# ______ Remove Turbolinks and CoffeeScript from Gemfile _______
run "sed -i '' '/turbolinks/d' ./Gemfile"
run "sed -i '' '/coffee/d' ./Gemfile"

# ______ Configure installed gems _______
after_bundle do
  # ______ Convert to HAML _______
  rails_command 'haml:erb2haml' # Setting HAML_RAILS_DELETE_ERB=true does not have an effect, it will still prompt
  
  # ______ Configure Rspec _______
  run 'spring stop'
  rails_command 'generate rspec:install'
  run 'rm -rf test/'
  run 'echo "--format documentation" >> .rspec'
  
  IO.write('spec/rails_helper.rb', File.open('spec/rails_helper.rb') do |f|
                                     f.read.gsub('# Dir[Rails.root.join(\'spec\', \'support\', \'**\', \'*.rb\')].each { |f| require f }', 'Dir[Rails.root.join(\'spec\', \'support\', \'**\', \'*.rb\')].each { |f| require f }')
                                   end)

  # _____ Run rubocop _______
  run 'rubocop -a'

  # ______ Configure factory bot _______
  file 'spec/support/factory_bot.rb', <<-'CODE'
require 'factory_bot_rails'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
  CODE

  # ______ Configure capybara _______

  file 'spec/support/capybara.rb', <<-'CODE'
require 'selenium/webdriver'
require 'capybara'
require 'capybara/rspec'

Capybara.register_driver :headless_chrome do |app|

  options = Selenium::WebDriver::Chrome::Options.new(
    args: %w[headless disable-gpu no-sandbox]
  )
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :headless_chrome
  CODE

  # ______ Configure capybara screenshot _______
  file 'spec/support/capybara_screenshot.rb', <<-'CODE'
require 'capybara-screenshot/rspec'

Capybara::Screenshot.autosave_on_failure = true
Capybara.asset_host = 'http://localhost:3000'

Capybara::Screenshot.webkit_options = { width: 1440, height: 900 }
Capybara::Screenshot.register_filename_prefix_formatter(:rspec) do |example|
  "screenshot_#{example.description.tr(' ', '-').gsub(%r{^.*\/spec\/}, '')}"
end
Capybara::Screenshot.prune_strategy = :keep_last_run
Capybara::Screenshot.register_driver(:headless_chrome) do |driver, path|
  driver.browser.save_screenshot(path)
end
  CODE

  # ______ Configure site prism _______
  file 'spec/support/site_prism.rb', <<-'CODE'
require 'site_prism'

Dir[Rails.root.join('spec/page_objects/**/*.rb')].sort { |path| path.include?('shared') ? 0 : 1 }
                                                 .each { |f| require f }
  CODE

  file 'spec/page_objects/shared/layout_page.rb', <<-'CODE'
class LayoutPage < SitePrism::Page
end
  CODE

  file "spec/page_objects/#{@app_name}_site.rb", <<-CODE
class #{@app_name.capitalize}Site < SitePrism::Page
  # example page (reads from an example file called spec/page_objects/process_page.rb)
  # def process_page
  #   @process_page ||= ProcessPage.new
  # end
end
  CODE

  # ______ Configure VCR _______
  if vcr
    file 'spec/support/vcr.rb', <<-'CODE'
require 'webmock/rspec'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    record: :new_episodes,
    allow_playback_repeats: true
  }
end
  CODE
end

  # ______ Remove Turbolinks From Views  _______
  run "sed -i '' '/turbolinks/d' ./app/assets/javascripts/application.js"

  main_view = 'app/views/layouts/application.html.haml'
  IO.write(main_view, File.open(main_view) do |f|
                        f.read.gsub(", 'data-turbolinks-track': 'reload'", '')
                      end)

  if foundation
  # ______ Install Foundation  _______
    rails_command 'g foundation:install'

  # ______ Configure Foundation CSS  _______
    run 'rm app/assets/stylesheets/application.css'
    file 'app/assets/stylesheets/application.scss', <<-CODE
// Foundation
@import 'foundation_and_overrides';

// Mixins
@import 'mixins/bem';

  CODE

    file 'app/assets/stylesheets/mixins/_bem.scss', <<-'CODE'
// Block Element
@mixin element($element) {
  &__#{$element} {
    @content;
  }
}

// Block Modifier
@mixin modifier($modifier) {
  &--#{$modifier} {
    @content;
  }
}
  CODE

  # ______ Configure Foundation JS  _______
  run 'rm app/assets/javascripts/application.js'
  file 'app/assets/javascripts/application.js', <<-CODE
//= require jquery
//= require activestorage
//= require foundation
//= require_tree .

$(function(){ $(document).foundation(); });
  CODE
end

  # ______ Configure git and commit  _______
  git :init
  git add: '.'
  git commit: %( -m 'Rails project set up with Boost template' )
end
