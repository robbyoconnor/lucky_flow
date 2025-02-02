require "selenium"
require "habitat"

class LuckyFlow; end

require "./lucky_flow/**"
require "file_utils"

class LuckyFlow
  include LuckyFlow::Expectations
  SERVER = LuckyFlow::Server::INSTANCE

  Habitat.create do
    setting screenshot_directory : String = "./tmp/screenshots"
    setting base_uri : String
    setting retry_delay : Time::Span = 10.milliseconds
    setting stop_retrying_after : Time::Span = 1.second
    setting chromedriver_path : String? = nil
    setting browser_binary : String? = nil
  end

  def visit(path : String)
    session.url = "#{settings.base_uri}#{path}"
  end

  def visit(action : Lucky::Action.class, as user : User? = nil)
    visit(action.route, as: user)
  end

  def visit(route_helper : Lucky::RouteHelper, as user : User? = nil)
    url = route_helper.url
    uri = URI.parse(url)
    if uri.query && user
      url += "&backdoor_user_id=#{user.id}"
    elsif uri.query.nil? && user
      url += "?backdoor_user_id=#{user.id}"
    end
    session.url = url
  end

  def open_screenshot(process = Process, time = Time.now, fullsize = false) : Void
    filename = generate_screenshot_filename(time)
    take_screenshot(filename, fullsize)
    process.new(command: "#{open_command(process)} #{filename}", shell: true)
  end

  def take_screenshot(filename : String = generate_screenshot_filename, fullsize : Bool = true)
    if fullsize
      with_fullsized_page { session.save_screenshot(filename) }
    else
      session.save_screenshot(filename)
    end
  end

  private def generate_screenshot_filename(time : Time = Time.now)
    "#{settings.screenshot_directory}/#{time.to_unix}.png"
  end

  def expand_page_to_fullsize
    width = session.execute("return Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth);").as_i
    height = session.execute("return Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight);").as_i
    window = session.window
    window.resize_to(width + 100, height + 100)
  end

  def with_fullsized_page(&block)
    original_size = session.window.rect
    expand_page_to_fullsize
    yield
  ensure
    session.window.rect = original_size
  end

  private def open_command(process) : String
    ["open", "xdg-open", "kde-open", "gnome-open"].find do |command|
      !!process.find_executable(command)
    end || raise "Could not find a way to open the screenshot"
  end

  def click(css_selector : String)
    el(css_selector).click
  end

  # Set the text of a form field, clearing any existing text
  #
  # ```crystal
  # fill("comment:body", with: "Lucky is great!")
  # ```
  def fill(name_attr : String, with value : String)
    field(name_attr).fill(value)
  end

  # Add text to the end of a field
  #
  # ```crystal
  # fill("comment:body", with: "Lucky is:")
  #
  # append("comment:body", " So much fun!")
  # ```
  def append(name_attr : String, with value : String)
    field(name_attr).append(value)
  end

  # Fill a form created by Lucky that uses an Avram::SaveOperation
  #
  # Note that Lucky and Avram are required to use this method
  #
  # ```
  # fill_form QuestionForm,
  #   title: "Hello there!",
  #   body: "Just wondering what day it is"
  # ```
  def fill_form(
    form : Avram::SaveOperation.class | Avram::Operation.class,
    **fields_and_values
  )
    fields_and_values.each do |name, value|
      fill "#{form.param_key}:#{name}", with: value
    end
  end

  def el(css_selector : String, text : String)
    Element.new(css_selector, text)
  end

  def el(css_selector : String)
    Element.new(css_selector)
  end

  def field(name_attr : String)
    Element.new("[name='#{name_attr}']")
  end

  def session
    self.class.session
  end

  def self.session
    SERVER.session
  end

  def self.shutdown
    SERVER.shutdown
  end

  def self.reset
    SERVER.reset
  end
end
