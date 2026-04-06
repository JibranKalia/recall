module MarkdownHelper
  private

  def markdown_renderer
    MarkdownHelper.renderer
  end

  def render_markdown(text)
    return "".html_safe if text.blank?
    text = text.scrub("")
    markdown_renderer.render(text).html_safe
  end

  def self.renderer
    @renderer ||= begin
      require "redcarpet"
      require "rouge"
      require "rouge/plugins/redcarpet"
      klass = Class.new(Redcarpet::Render::HTML) { include Rouge::Plugins::Redcarpet }
      html_renderer = klass.new(hard_wrap: true, link_attributes: { target: "_blank", rel: "noopener" })
      Redcarpet::Markdown.new(html_renderer,
        fenced_code_blocks: true,
        autolink: true,
        tables: true,
        strikethrough: true,
        superscript: true,
        no_intra_emphasis: true,
        lax_spacing: true,
        space_after_headers: true,
        highlight: true
      )
    end
  end
end
