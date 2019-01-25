# Rails Application Template

To set up a new project:
```ruby
rails new project-name -m path/to/template.rb
# OR
rails new project-name -m https://github.com/boost/rails-application-template/blob/master/template.rb
```

To apply to an existing project:
```ruby
bin/rails app:template LOCATION=path/to/template.rb
```

* Rails Guides: [Rails Application Templates](https://guides.rubyonrails.org/rails_application_templates.html)


This template does the following:

  - Install GEMS WE LOVE
  - Basic Travis configuration
  - Configures The Rubocop
  - Remove Turbolinks and CoffeeScript from Gemfile, and from views
  - Convert to HAML
  - Configure Rspec
    - Configure factory bot
    - Configure capybara
    - Configure capybara screenshot
    - Configure site prism
    - Configure VCR
  - Install and configure Foundation
