module ProjectsHelper
  # Genera un rango compacto de páginas para la paginación, ej: [1, 2, 3, :ellipsis, 7]
  def pagination_page_numbers(current_page, total_pages)
    return [1] if total_pages <= 1

    pages = ([1, total_pages] + ((current_page - 1)..(current_page + 1)).to_a)
              .select { |p| p.between?(1, total_pages) }
              .uniq
              .sort

    pages.each_with_object([]) do |page, result|
      result << :ellipsis if result.last.is_a?(Integer) && page - result.last > 1
      result << page
    end
  end
end
