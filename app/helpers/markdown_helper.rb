module MarkdownHelper
  class RougeRenderer < Redcarpet::Render::HTML
    include Rouge::Plugins::Redcarpet
  end

  def render_markdown(text)
    return "".html_safe if text.blank?

    renderer = RougeRenderer.new(hard_wrap: true, link_attributes: { target: "_blank", rel: "noopener" })
    markdown = Redcarpet::Markdown.new(renderer,
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

    markdown.render(text).html_safe
  end
end
