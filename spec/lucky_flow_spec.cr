require "./spec_helper"

describe LuckyFlow do
  it "can visit a URL" do
    TestServer.route "/home", "<span flow-id='heading'>Home</span>"
    flow = LuckyFlow.new

    flow.visit("/home")

    flow.el("@heading", text: "Home").should be_on_page
  end

  it "can find element's text" do
    flow = visit_page_with "<span flow-id='heading'>Home</span>"

    flow.el("@heading").text.should eq "Home"
  end

  describe "helpful errors" do
    it "gives a suggestion if element not found" do
      flow = visit_page_with "<span flow-id='heading'>Home</span>"

      expect_raises LuckyFlow::ElementNotFoundError, "@heading" do
        flow.el("@harding").displayed?
      end
    end

    it "does not give a suggestion if not similar enough" do
      flow = visit_page_with "<span flow-id='heading'>Home</span>"

      expect_to_raise_without_suggestion do
        flow.el("@headboard").displayed?
      end
    end

    it "does not give recommendations for non flow-ids" do
      flow = visit_page_with "<span class='heading'>Home</span><span flow-id='headingg'></span>"

      expect_to_raise_without_suggestion do
        flow.el(".headinggg").displayed?
      end
    end

    it "does not give a suggestion if the flow id is correct but text is not" do
      flow = visit_page_with "<span flow-id='heading'>Home</span>"

      expect_to_raise_without_suggestion do
        flow.el("@heading", text: "Not Home").displayed?
      end
    end
  end

  it "can find a flow id" do
    flow = visit_page_with "<h1 flow-id='test-me'>Hello</h1>"
    flow.el("@test-me", text: "Hello").should be_on_page
    flow.el("@test-me", text: "Not here").should_not be_on_page
  end

  it "can find a generic CSS selector" do
    flow = visit_page_with "<h1 class='jumbotron'>Hello</h1>"
    flow.el(".jumbotron", text: "Hello").should be_on_page
    flow.el(".jumbotron", text: "Not here").should_not be_on_page
  end

  it "can fill in text" do
    flow = visit_page_with <<-HTML
      <input name="question:title"/>
      <input name="question:body"/>
    HTML
    flow.field("question:title").value.should eq ""
    flow.field("question:body").value.should eq ""

    flow.field("question:title").fill("Joe")
    flow.fill "question:body", with: "Sally"

    flow.field("question:title").value.should eq "Joe"
    flow.field("question:body").value.should eq "Sally"
  end

  it "clears existing text before filling" do
    flow = visit_page_with <<-HTML
      <input name="question:title"/>
      <input name="question:body"/>
    HTML

    flow.field("question:title").fill("Joe")
    flow.fill "question:body", with: "Sally"
    flow.field("question:title").fill("emacs")
    flow.fill "question:body", with: "vim"

    flow.field("question:title").value.should eq "emacs"
    flow.field("question:body").value.should eq "vim"
  end

  it "appends to existing text" do
    flow = visit_page_with <<-HTML
      <input name="question:title"/>
      <input name="question:body"/>
    HTML

    flow.field("question:title").fill("Joe")
    flow.fill "question:body", with: "Sally"
    flow.field("question:title").append(" (he/him)")
    flow.append "question:body", with: " (she/her)"

    flow.field("question:title").value.should eq "Joe (he/him)"
    flow.field("question:body").value.should eq "Sally (she/her)"
  end

  it "can get the value of an input" do
    flow = visit_page_with <<-HTML
      <input name="question:title" value="hello"/>
    HTML

    flow.field("question:title").value.should eq "hello"
  end

  it "can click elements" do
    TestServer.route "/target", "<h1>Target</h1>"
    flow = visit_page_with <<-HTML
      <h1>Home</h1>
      <a flow-id='target' href='/target'>Click Me</a>
    HTML
    flow.el("h1", text: "Home").should be_on_page

    flow.click("@target")

    flow.el("h1", text: "Target").should be_on_page
  end

  it "can open screenshots" do
    flow = LuckyFlow.new
    fake_process = FakeProcess
    time = Time.utc

    flow.open_screenshot(fake_process, time)

    fake_process.shell.should be_true
    fake_process.command.should eq "open ./tmp/screenshots/#{time.to_unix}.png"
  end

  it "can open fullsize screenshots" do
    flow = LuckyFlow.new
    fake_process = FakeProcess
    time = Time.utc

    flow.open_screenshot(fake_process, time, fullsize: true)

    fake_process.shell.should be_true
    fake_process.command.should eq "open ./tmp/screenshots/#{time.to_unix}.png"
  end

  it "can reset the session" do
    flow = LuckyFlow.new
    flow.session.cookies.set("hello", "world")
    flow.session.cookies.get("hello").value.should eq "world"

    LuckyFlow.reset

    expect_raises KeyError do
      flow.session.cookies.get("hello").value
    end
  end
end

private class FakeProcess
  class_property command : String?
  class_property shell : Bool?

  def initialize(command, shell)
    @@command = command
    @@shell = shell
  end

  def self.find_executable(string)
    "/fake_path_to_executable"
  end
end

private def expect_to_raise_without_suggestion
  error = expect_raises LuckyFlow::ElementNotFoundError do
    yield
  end
  error.to_s.should_not contain("Did you mean")
end
