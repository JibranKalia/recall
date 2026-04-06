class LLM::PromptBuilder
  def self.build(&block)
    builder = new
    block.call(builder)
    builder.to_s
  end

  def initialize
    @parts = []
  end

  # Tag with string content:  p.rules("- no preamble")
  # Tag with block content:   p.context { |c| c.text("hello") }
  # Tag with attrs:           p.message(role: "user") { "hello" }
  def method_missing(tag, *args, **attrs, &block)
    if block
      child = self.class.new
      result = block.call(child)
      # If block returned a string and child has no parts, use the string
      content = child.empty? ? result.to_s : child.to_s
    else
      content = args.first.to_s
    end

    @parts << format_tag(tag, content, **attrs)
    self
  end

  def respond_to_missing?(*, **)
    true
  end

  # Raw text without tags
  def text(str)
    @parts << str.to_s
    self
  end

  def empty?
    @parts.empty?
  end

  def to_s
    @parts.join("\n\n")
  end

  private

  def format_tag(tag, content, **attrs)
    open = if attrs.any?
      attr_str = attrs.map { |k, v| " #{k}=\"#{v}\"" }.join
      "<#{tag}#{attr_str}>"
    else
      "<#{tag}>"
    end
    "#{open}\n#{content}\n</#{tag}>"
  end
end
