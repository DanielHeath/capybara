# frozen_string_literal: true

require 'spec_helper'
require 'selenium-webdriver'
require 'shared_selenium_session'
require 'shared_selenium_node'
require 'rspec/shared_spec_matchers'

Selenium::WebDriver::Edge::Service.driver_path = '/usr/local/bin/msedgedriver'
Selenium::WebDriver::EdgeChrome.path = '/Applications/Microsoft Edge Canary.app/Contents/MacOS/Microsoft Edge Canary'

Capybara.register_driver :selenium_edge do |app|
  # ::Selenium::WebDriver.logger.level = "debug"
  Capybara::Selenium::Driver.new(app, browser: :edge_chrome).tap do |driver|
    driver.browser
    driver.download_path = Capybara.save_path
  end
end

module TestSessions
  SeleniumEdge = Capybara::Session.new(:selenium_edge, TestApp)
end

skipped_tests = %i[response_headers status_code trigger]

Capybara::SpecHelper.log_selenium_driver_version(Selenium::WebDriver::Edge) if ENV['CI']

Capybara::SpecHelper.run_specs TestSessions::SeleniumEdge, 'selenium', capybara_skip: skipped_tests do |example|
  # case example.metadata[:description]
  # when /#refresh it reposts$/
  #   skip 'Edge insists on prompting without providing a way to suppress'
  # when /should be able to open non-http url/
  #   skip 'Crashes'
  # when /when Capybara.always_include_port is true/
  #   skip 'Crashes'
  # end
end

RSpec.describe 'Capybara::Session with Edge', capybara_skip: skipped_tests do
  include Capybara::SpecHelper
  ['Capybara::Session', 'Capybara::Node', Capybara::RSpecMatchers].each do |examples|
    include_examples examples, TestSessions::SeleniumEdge, :selenium_edge
  end

  context 'storage' do
    describe '#reset!' do
      it 'clears storage by default' do
        session = TestSessions::SeleniumEdge
        session.visit('/with_js')
        session.find(:css, '#set-storage').click
        session.reset!
        session.visit('/with_js')
        expect(session.evaluate_script('Object.keys(localStorage)')).to be_empty
        expect(session.evaluate_script('Object.keys(sessionStorage)')).to be_empty
      end

      it 'does not clear storage when false' do
        session = Capybara::Session.new(:selenium_edge_not_clear_storage, TestApp)
        session.visit('/with_js')
        session.find(:css, '#set-storage').click
        session.reset!
        session.visit('/with_js')
        expect(session.evaluate_script('Object.keys(localStorage)')).not_to be_empty
        expect(session.evaluate_script('Object.keys(sessionStorage)')).not_to be_empty
      end
    end
  end

  context 'timeout' do
    it 'sets the http client read timeout' do
      expect(TestSessions::SeleniumEdge.driver.browser.send(:bridge).http.read_timeout).to eq 30
    end
  end

  describe 'filling in Chrome-specific date and time fields with keystrokes' do
    let(:datetime) { Time.new(1983, 6, 19, 6, 30) }
    let(:session) { TestSessions::SeleniumEdge }

    before do
      session.visit('/form')
    end

    it 'should fill in a date input with a String' do
      session.fill_in('form_date', with: '06/19/1983')
      session.click_button('awesome')
      expect(Date.parse(extract_results(session)['date'])).to eq datetime.to_date
    end

    it 'should fill in a time input with a String' do
      session.fill_in('form_time', with: '06:30A')
      session.click_button('awesome')
      results = extract_results(session)['time']
      expect(Time.parse(results).strftime('%r')).to eq datetime.strftime('%r')
    end

    it 'should fill in a datetime input with a String' do
      session.fill_in('form_datetime', with: "06/19/1983\t06:30A")
      session.click_button('awesome')
      expect(Time.parse(extract_results(session)['datetime'])).to eq datetime
    end
  end

  describe 'using subclass of selenium driver' do
    it 'works' do
      session = Capybara::Session.new(:selenium_driver_subclass_with_edge, TestApp)
      session.visit('/form')
      expect(session).to have_current_path('/form')
    end
  end

  describe 'log access' do
    it 'does not error getting log types' do
      skip if Gem::Version.new(session.driver.browser.capabilities['chrome']['chromedriverVersion'].split[0]) < Gem::Version.new('75.0.3770.90')
      expect do
        session.driver.browser.manage.logs.available_types
      end.not_to raise_error
    end

    it 'does not error when getting logs' do
      expect do
        session.driver.browser.manage.logs.get(:browser)
      end.not_to raise_error
    end
  end

end
