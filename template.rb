vcr = yes? 'Do you want to install VCR?'
foundation = yes? 'Do you want to install Foundation?'
vue = yes? 'Do you want to installinstall Vue?'

# ______ GEMS WE LOVE _______

gem_group :test do
  gem 'capybara-screenshot'
  gem 'chromedriver-helper'
  gem 'factory_bot_rails'
  gem 'site_prism'
  gem 'vcr' if vcr
  gem 'webmock' if vcr
end

gem_group :development, :test do
  gem 'pry-rails'
  gem 'rspec-rails', '~> 4.0.1'
  gem 'rubocop', '~> 0.68', require: false
  gem 'boost-styles', git: 'https://github.com/boost/boost-styles.git', require: false
end

if foundation
  gem 'sprockets-es6'
  gem 'jquery-rails', '~> 4.3', '>= 4.3.3'
  gem 'foundation-rails'
  gem 'autoprefixer-rails'
end

# require gem
gem 'haml-rails'

# ______ Remove Turbolinks and CoffeeScript from Gemfile _______
run "sed -i '' '/turbolinks/d' ./Gemfile"
run "sed -i '' '/coffee/d' ./Gemfile"

# ______ Configure installed gems _______
after_bundle do
  # ______ Convert to HAML _______
  rails_command 'haml:erb2haml' # Setting HAML_RAILS_DELETE_ERB=true does not have an effect, it will still prompt
  
  # ______ install sass loader for webpacker
  run 'npm i --save-dev node-sass sass-loader@10.2.0 style-loader'
  run 'npm install'
  run 'npm rebuild'

  if vue
  run 'npm i vue vue-loader vue-template-compiler'
  file 'config/webpack/loaders/vue.js', <<-CODE
module.exports = {
  test: /\.vue(\.erb)?$/,
  use: [{
    loader: 'vue-loader',
  }],
};
  CODE

  file 'config/webpack/environment.js', <<-CODE
const { environment } = require('@rails/webpacker');
const { VueLoaderPlugin } = require('vue-loader');
const vue = require('./loaders/vue');

environment.plugins.prepend('VueLoaderPlugin', new VueLoaderPlugin());
environment.loaders.prepend('vue', vue);

const nodeModulesLoader = environment.loaders.get('nodeModules')
if (!Array.isArray(nodeModulesLoader.exclude)) {
  nodeModulesLoader.exclude = (nodeModulesLoader.exclude == null)
    ? []
    : [nodeModulesLoader.exclude]
}
nodeModulesLoader.exclude.push(/sanitize-html/)

module.exports = environment;
  CODE

  file 'app/javascript/components/app.vue', <<-CODE
<template>
  <div id="app">
    <p>{{ message }}</p>
    <div class="">
      {{count}} <button @click="increase">+</button>
    </div>
  </div>
</template>

<script>
export default {
  data: function () {
    return {
      message: "Hello Vue!",
      count: 0
    }
  },
  methods: {
    increase () {
      this.count++
    }
  }
}
</script>

<style scoped>
p {
  font-size: 2em;
  text-align: center;
}
</style>
  CODE

  file 'app/javascript/packs/app.js', <<-CODE
import Vue from 'vue'
import App from '../components/app.vue'

document.body.appendChild(document.createElement('hello'))
new Vue(App).$mount('hello')

  CODE
  end

# ______ The cop _______
  # rails_command 'generate boost_styles:install'

  # ______ Configure Rspec _______
  rails_command 'generate rspec:install'
  run 'rm -rf test/'
  run 'echo "--format documentation" >> .rspec'
  
  IO.write('spec/rails_helper.rb', File.open('spec/rails_helper.rb') do |f|
    f.read.gsub('# Dir[Rails.root.join(\'spec\', \'support\', \'**\', \'*.rb\')].each { |f| require f }', 'Dir[Rails.root.join(\'spec\', \'support\', \'**\', \'*.rb\')].each { |f| require f }')
  end)


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
  # run 'rm app/assets/javascripts/application.js'
  file 'app/assets/javascripts/application.js', <<-CODE
//= require jquery
//= require activestorage
//= require foundation
//= require_tree .

$(function(){ $(document).foundation(); });
  CODE
else

# ______ Configure Foundation CSS  _______
  run 'rm app/assets/stylesheets/application.css'
  file 'app/assets/stylesheets/application.scss', <<-CODE

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

  # ______ Configure  JS  _______
  # run 'rm app/assets/javascripts/application.js'
  file 'app/assets/javascripts/application.js', <<-CODE
//= require_tree .
  CODE
end

  # ______ Configure SASS with webpacker JS  _____
  run 'rm app/javascript/packs/application.js'
  file 'app/javascript/packs/application.js', <<-CODE
import * as ActiveStorage from "@rails/activestorage"
import "channels"
import './application.scss';

ActiveStorage.start()
  CODE

  file 'app/javascript/packs/application.scss', <<-CODE
@import '../../assets/stylesheets/mixins/bem.scss';
  CODE

  # ______ Configure Foundation JS  _______
  run 'rm app/views/layouts/application.html.haml'
  file 'app/views/layouts/application.html.haml', <<-CODE
!!!
%html
  %head
    %meta{:content => "text/html; charset=UTF-8", "http-equiv" => "Content-Type"}/
    %title
    %meta{:content => "width=device-width,initial-scale=1", :name => "viewport"}/
    = csrf_meta_tags
    = csp_meta_tag
    = stylesheet_link_tag 'application', media: 'all'
    = javascript_pack_tag 'application'
    = stylesheet_pack_tag 'application'
  %body
    = yield
    .container__test
      test
  CODE

  #_______ DB prepare ______
  rails_command 'db:prepare'

  #_______ github test ______

  file '.github/workflows/test.yml', <<-CODE
  
name: Tests
on: pull_request

jobs:
  test_ruby_units:
    runs-on: self-hosted

    services:
      mysql:
        image: mysql:5.7
        ports:
        - 3306
        env:
          MYSQL_ROOT_PASSWORD: root
        options: --health-cmd="mysqladmin ping" --health-interval=10s --health-timeout=5s --health-retries=3

    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        bundler-cache: true
    - run: bundle install

    - name: Setup Node
      uses: actions/setup-node@v2

    - name: Yarn cache dir path
      id: yarn-cache-dir-path
      run: echo "::set-output name=dir::$(yarn cache dir)"

    - name: Yarn cache
      id: yarn-cache
      uses: actions/cache@v2
      with:
        path: ${{ steps.yarn-cache-dir-path.outputs.dir }}
        key: ${{ runner.os }}-yarn-${{ hashFiles('**/yarn.lock') }}
        restore-keys: |
          ${{ runner.os }}-yarn-

    - name: Yarn install
      run: yarn install

    - name: Run RSpec unit tests
      env:
        RAILS_ENV: test
        DATABASE_URL: mysql2://root:root@127.0.0.1/supergold_rails_test
        MYSQL_PORT: "${{ job.services.mysql.ports['3306'] }}"
        RAILS_MASTER_KEY: ${{ secrets.MASTER_KEY }}
        API_PUBLIC_KEY: webapiuser
        API_SECRET_KEY: ${{secrets.API_SECRET_KEY}}
        TZ: Pacific/Auckland
      run: |
        RAILS_ENV=test bundle exec rails db:create db:test:prepare
        bundle exec rspec --force-color --fail-fast
CODE

  # ______ Configure git and commit  _______
  git :init
  git add: '.'
  git commit: %( -m 'Rails project set up with Boost template' )
end
