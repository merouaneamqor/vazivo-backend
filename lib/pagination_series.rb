# frozen_string_literal: true

# SEO-friendly pagination series: which page numbers to show (left/right window,
# around current page, and "tens" for large page counts). Standalone helper;
# do not reopen Pagy.
module PaginationSeries
  DEFAULT_LEFT = 1
  DEFAULT_RIGHT = 1
  DEFAULT_WINDOW = 2

  module_function

  # @param current_page [Integer]
  # @param total_pages [Integer]
  # @param left [Integer] number of pages at start (default 1)
  # @param right [Integer] number of pages at end (default 1)
  # @param window [Integer] pages each side of current (default 2)
  # @return [Array<Integer>] sorted page numbers to display
  def call(current_page:, total_pages:, left: DEFAULT_LEFT, right: DEFAULT_RIGHT, window: DEFAULT_WINDOW)
    return [] if total_pages < 1

    page = current_page.to_i.clamp(1, total_pages)

    left_window_plus_one = (1..(left + 1)).to_a
    right_window_plus_one = ([total_pages - right, 1].max..total_pages).to_a
    inside_window_plus_each_sides = ([page - window - 1, 1].max..[page + window + 1, total_pages].min).to_a
    current_hundred = page / 100
    tens = (1..10).map { |n| (n * 10) + (current_hundred * 100) }

    (left_window_plus_one | inside_window_plus_each_sides | tens | right_window_plus_one)
      .select { |x| x.between?(1, total_pages) }
      .sort
  end
end
