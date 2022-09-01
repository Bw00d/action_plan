# Status Summary

## Summary
An application for generating an Incident Action plan for a wildfire or other incident or planned
event. This is a work in progress and will need plenty of testing in the wild before it can be
shared with other users. It was built on the Zen-Rails-Base-Application template.

## Features
User can create and incident and build a daily plan for the using standard ICS forms. The user can build a plan as a basic ICS-201, or the user can build an IAP using standard forms typically included in the IAP.


## Development Environment Dependencies
- Currently Rails 5.2.4.3
- Ruby 2.4.4
- [Yarn](https://yarnpkg.com/en/docs/install)
- Required for running JavaScript-enabled feature specs:
    - [Selenium](http://www.seleniumhq.org/projects/webdriver/)
    - [ChromeDriver](https://sites.google.com/a/chromium.org/chromedriver/)
    - [Xvfb](https://www.x.org/archive/X11R7.6/doc/man/man1/Xvfb.1.xhtml) if
    running feature specs on a console-only (no graphical interface) *nix
    environment.


## TODO
- Fix checkboxes on 202 to us bip
- Add upload for cover photo and maps to AWS
- Add open task tracker or 24-48-72
- Install and configure the [Secure Headers
gem](https://github.com/twitter/secureheaders).
- Set up CodeClimate with Rubocop, Reek, Brakeman, and ESLint engines.
- Set up continuous integration.
- Use Yarn instead of gems to install front end libraries such as jQuery and 
Select2.
- Add an asterisk to the labels of required form fields.

## License

Released under the [MIT License](https://opensource.org/licenses/MIT).
