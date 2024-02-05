defmodule Sparkline.Line do
  @moduledoc """
  `Sparkline.Line` uses a list of datapoints to return a line chart in SVG format.

  ## Usage example:

  ``` elixir
  # Datapoints
  datapoints = [{1, 1}, {2, 2}, {3, 3}]

  # A very simple line chart
  Sparkline.Line.to_svg(datapoints)

  # A line chart with different sizes
  Sparkline.Line.to_svg(datapoints, width: 240, height: 80)

  # A complete example of a line chart
  options = [
    width: 100,
    height: 40,
    padding: 0.5,
    show_dot: false,
    dot_radius: 0.1,
    dot_color: "rgb(255, 255, 255)",
    line_color: "rgba(166, 218, 149)",
    line_width: 0.05,
    line_smoothing: 0.1
  ]

  Sparkline.Line.to_svg(datapoints, options)
  ```

  ## Options

  Use the following options to customize the chart:

  - `width`: The width of the chart, defaults to `200`.
  - `height`: The height of the chart, defaults to `100`.
  - `padding`: The padding of the chart, defaults to `6`.
  - `show_dot`: A boolean to decide whether to show dots or not, defaults to `true`.
  - `dot_radius`: The radius of the dots, defaults to `1`.
  - `dot_color`: The color of the dots, defaults to `"black"`.
  - `show_line`: A boolean to decide whether to show the line or not, defaults to `true`.
  - `line_width`: The width of the line, defaults to `0.25`.
  - `line_color`: The color of the line, defaults to `"black"`.
  - `line_smoothing`: The smoothing of the line (`0` = no smoothing, above `0.5` it becomes unreadable),
    defaults to `0.2`.
  - `show_area`: A boolean to decide whether to show the area under the line or not, defaults to `false`.
  - `area_color`: The color of the area under the line, defaults to `"rgba(0, 0, 0, 0.2)"`.
  - `placeholder`: A placeholder for an empty chart, defaults to `"No data"`.

  ## Datapoints

  A datapoint can be a pair of `DateTime` and `number`, `Date` and `number`, `Time` and `number`,
  or simply two `numbers`. However, the datapoints in a list must all be of the same type.

  ``` elixir
  # Datapoints
  datapoints = [{1, 1}, {2, 2}, {3, 3}]

  # Datapoints with DateTime
  datapoints = [{~N[2021-01-01 00:00:00], 1}, {~N[2021-01-02 00:00:00], 2}, {~N[2021-01-03 00:00:00], 3}]

  # Datapoints with Date
  datapoints = [{~D[2021-01-01], 1}, {~D[2021-01-02], 2}, {~D[2021-01-03], 3}]

  # Datapoints with Time
  datapoints = [{~T[00:00:00], 1}, {~T[00:00:00], 2}, {~T[00:00:00], 3}]
  ```
  """

  @typedoc """
  A datapoint can be a pair of DateTime and number, Date and number, Time and number,
  or simply two numbers.
  """
  @type datapoint ::
          {DateTime.t(), number()}
          | {Date.t(), number()}
          | {Time.t(), number()}
          | {number(), number()}

  @typedoc """
  A list of datapoints. The data types in the list correspond to those defined for
  datapoint.
  """
  @type datapoints ::
          list({DateTime.t(), number()})
          | list({Date.t(), number()})
          | list({Time.t(), number()})
          | list({number(), number()})

  @typedoc "An option for the chart."
  @type option ::
          {:width, number()}
          | {:height, number()}
          | {:padding, number()}
          | {:show_dot, boolean()}
          | {:dot_radius, number()}
          | {:dot_color, String.t()}
          | {:show_line, boolean()}
          | {:line_width, number()}
          | {:line_color, String.t()}
          | {:line_smoothing, float()}
          | {:show_area, boolean()}
          | {:area_color, String.t()}
          | {:placeholder, String.t()}

  @typedoc "An options list for the chart."
  @type options :: list(option())

  # Default options
  @default_options [
    width: 200,
    height: 100,
    padding: 6,
    show_dot: true,
    dot_radius: 1,
    dot_color: "black",
    show_line: true,
    line_width: 0.25,
    line_color: "black",
    line_smoothing: 0.2,
    show_area: false,
    area_color: "rgba(0, 0, 0, 0.2)",
    placeholder: "No data"
  ]

  defexception [:message]

  @doc """
  Return a valid SVG document representing a line chart with the given datapoints.

  ## Examples

      iex> Sparkline.Line.to_svg([{1, 1}, {2, 2}, {3, 3}])
      {:ok, svg_string}

      iex> Sparkline.Line.to_svg([{1, 1}, {2, 2}, {3, 3}], width: 240, height: 80)
      {:ok, svg_string}

  """
  @spec to_svg(datapoints()) :: {:ok, Sparkline.svg()} | {:error, atom()}
  @spec to_svg(datapoints(), options()) :: {:ok, Sparkline.svg()} | {:error, atom()}
  def to_svg(datapoints, options \\ []) do
    options = default_options(options)
    padding = Keyword.get(options, :padding)

    with :ok <- check_dimension(Keyword.get(options, :width), padding),
         :ok <- check_dimension(Keyword.get(options, :height), padding),
         {:ok, datapoints} <- clean_datapoints(datapoints) do
      svg =
        if Enum.empty?(datapoints) do
          draw_chart([], options)
        else
          {min_max_x, min_max_y} = compute_min_max(datapoints)

          datapoints
          |> compute_datapoints(min_max_x, min_max_y, options)
          |> draw_chart(options)
        end

      {:ok, svg}
    end
  end

  @doc """
  Return a valid SVG document representing a line chart with the given datapoints.

  ## Examples

      iex> Sparkline.Line.to_svg!([{1, 1}, {2, 2}, {3, 3}])
      svg_string

      iex> Sparkline.Line.to_svg!([{1, 1}, {2, 2}, {3, 3}], width: 240, height: 80)
      svg_string

  """
  @spec to_svg!(datapoints()) :: Sparkline.svg()
  @spec to_svg!(datapoints(), options()) :: Sparkline.svg()
  def to_svg!(datapoints, options \\ []) do
    case to_svg(datapoints, options) do
      {:ok, svg} -> svg
      {:error, reason} -> raise(Sparkline.Line, Atom.to_string(reason))
    end
  end

  # Private functions

  @typep point :: %{x: number(), y: number()}
  @typep points :: list(point())
  @typep min_max :: {number(), number()}

  @spec check_dimension(number(), number()) :: :ok | {:error, atom()}
  defp check_dimension(length, padding) do
    if length - 2 * padding > 0,
      do: :ok,
      else: {:error, :invalid_dimension}
  end

  @spec clean_datapoints(datapoints()) :: {:ok, datapoints()} | {:error, atom()}
  defp clean_datapoints(datapoints) do
    {datapoints, _type} =
      Enum.reduce_while(datapoints, {[], nil}, fn {x, y}, {datapoints, type} ->
        with {:ok, x, type} <- clean_x(x, type),
             {:ok, y} <- clean_y(y) do
          {:cont, {[{x, y} | datapoints], type}}
        else
          {:error, reason} -> {:halt, {{:error, reason}, type}}
        end
      end)

    case datapoints do
      {:error, reason} ->
        {:error, reason}

      datapoints ->
        datapoints =
          datapoints
          |> Enum.uniq_by(fn {x, _} -> x end)
          |> Enum.sort_by(fn {x, _} -> x end)

        {:ok, datapoints}
    end
  end

  @spec clean_x(DateTime.t() | Date.t() | Time.t() | number(), atom()) ::
          {:ok, number(), atom()} | {:error, atom()}
  defp clean_x(x, nil) when is_number(x) do
    clean_x(x, :number)
  end

  defp clean_x(%module{} = x, nil) when is_struct(x) do
    clean_x(x, module)
  end

  defp clean_x(%DateTime{} = datetime, DateTime) do
    {:ok, DateTime.to_unix(datetime), DateTime}
  end

  defp clean_x(%Date{} = date, Date) do
    {:ok, datetime} = DateTime.new(date, ~T[00:00:00])
    {:ok, DateTime.to_unix(datetime), Date}
  end

  defp clean_x(%Time{} = time, Time) do
    {seconds, _milliseconds} = Time.to_seconds_after_midnight(time)
    {:ok, seconds, Time}
  end

  defp clean_x(x, :number) when is_number(x) do
    {:ok, x, :number}
  end

  defp clean_x(x, _type) when is_number(x) or x.__struct__ in [DateTime, Date, Time] do
    {:error, :mixed_datapoints_types}
  end

  defp clean_x(_x, _type) do
    {:error, :invalid_x_type}
  end

  @spec clean_y(number()) :: {:ok, number()} | {:error, atom()}
  defp clean_y(y) when is_number(y) do
    {:ok, y}
  end

  defp clean_y(_y) do
    {:error, :invalid_y_type}
  end

  @spec compute_min_max(datapoints()) :: {min_max(), min_max()}
  defp compute_min_max(datapoints) do
    {{min_x, _}, {max_x, _}} = Enum.min_max_by(datapoints, fn {x, _} -> x end)
    {{_, min_y}, {_, max_y}} = Enum.min_max_by(datapoints, fn {_, y} -> y end)
    [{x, y} | _tail] = datapoints

    min_max_x = if max_x - min_x == 0, do: {0, 2 * x}, else: {min_x, max_x}

    min_max_y =
      cond do
        max_y - min_y != 0 -> {min_y, max_y}
        y == 0 -> {-1, 1}
        true -> {0, 2 * y}
      end

    {min_max_x, min_max_y}
  end

  @spec compute_datapoints(datapoints(), min_max(), min_max(), options()) :: points()
  defp compute_datapoints(datapoints, {min_x, max_x}, {min_y, max_y}, options) do
    width = Keyword.get(options, :width)
    height = Keyword.get(options, :height)
    padding = Keyword.get(options, :padding)

    Enum.map(datapoints, fn {x, y} ->
      %{
        x: (x - min_x) / (max_x - min_x) * (width - padding * 2) + padding,
        y: height - (y - min_y) / (max_y - min_y) * (height - padding * 2) - padding
      }
    end)
  end

  @spec draw_chart(points(), options()) :: Sparkline.svg()
  defp draw_chart([], options) do
    """
    <svg width="100%" height="100%"
      viewBox="0 0 #{Keyword.get(options, :width)} #{Keyword.get(options, :height)}"
      xmlns="http://www.w3.org/2000/svg">
      <text x="50%" y="50%" text-anchor="middle">
        #{Keyword.get(options, :placeholder)}
      </text>
    </svg>
    """
  end

  defp draw_chart([%{x: x, y: y}], options) do
    left = Keyword.get(options, :padding)
    right = Keyword.get(options, :width) - 2 * Keyword.get(options, :padding)

    """
    <svg width="100%" height="100%"
      viewBox="0 0 #{Keyword.get(options, :width)} #{Keyword.get(options, :height)}"
      xmlns="http://www.w3.org/2000/svg">
      <path
        d="M#{left},#{format_float(y)}L#{right},#{format_float(y)}"
        fill="none"
        stroke="#{Keyword.get(options, :line_color)}"
        stroke-width="#{Keyword.get(options, :line_width)}" />
      <circle
        cx="#{format_float(x)}"
        cy="#{format_float(y)}"
        r="#{Keyword.get(options, :dot_radius)}"
        fill="#{Keyword.get(options, :dot_color)}" />
    </svg>
    """
  end

  defp draw_chart(datapoints, options) do
    """
    <svg width="100%" height="100%"
      viewBox="0 0 #{Keyword.get(options, :width)} #{Keyword.get(options, :height)}"
      xmlns="http://www.w3.org/2000/svg">
      #{if(Keyword.get(options, :show_area), do: draw_area(datapoints, options))}
      #{if(Keyword.get(options, :show_line), do: draw_line(datapoints, options))}
      #{if(Keyword.get(options, :show_dot), do: draw_dots(datapoints, options))}
    </svg>
    """
  end

  @spec draw_dots(points(), options()) :: String.t()
  defp draw_dots(datapoints, options) do
    Enum.map_join(datapoints, "", fn %{x: x, y: y} ->
      """
      <circle
        cx="#{format_float(x)}"
        cy="#{format_float(y)}"
        r="#{Keyword.get(options, :dot_radius)}"
        fill="#{Keyword.get(options, :dot_color)}" />
      """
    end)
  end

  @spec draw_line(points(), options()) :: String.t()
  defp draw_line(datapoints, options) do
    """
    <path
      d="#{compute_curve(datapoints, options)}"
      fill="none"
      stroke="#{Keyword.get(options, :line_color)}"
      stroke-width="#{Keyword.get(options, :line_width)}" />
    """
  end

  @spec draw_area(points(), options()) :: String.t()
  defp draw_area(datapoints, options) do
    # Extract the x value of the first datapoint to know where to finish the area.
    [%{x: x, y: _y} | _] = datapoints

    """
    <path
      d="#{[compute_curve(datapoints, options), "V", "#{Keyword.get(options, :height)}", "H", "#{x}", "Z"]}"
      fill="#{Keyword.get(options, :area_color)}"
      stroke="none" />
    """
  end

  @spec compute_curve(points(), options()) :: iolist()
  defp compute_curve([%{x: x, y: y} = curr | rest], options) do
    ["M#{tuple_to_string({x, y})}"]
    |> compute_curve(rest, curr, curr, options)
  end

  @spec compute_curve(iolist(), points(), point(), point(), options()) :: iolist()
  defp compute_curve(acc, [curr | [next | _] = rest], prev2, prev1, options) do
    acc
    |> curve_command(prev2, prev1, curr, next, options)
    |> compute_curve(rest, prev1, curr, options)
  end

  defp compute_curve(acc, [curr], prev2, prev1, options) do
    curve_command(acc, prev2, prev1, curr, curr, options)
  end

  @spec curve_command(iolist(), point(), point(), point(), point(), options()) :: iolist()
  defp curve_command(acc, prev2, prev1, curr, next, options) do
    cp1 = calculate_control_point(prev1, prev2, curr, :left, options)
    cp2 = calculate_control_point(curr, prev1, next, :right, options)
    currrent = {curr.x, curr.y}

    [acc, "C", tuple_to_string(cp1), " ", tuple_to_string(cp2), " ", tuple_to_string(currrent)]
  end

  @spec calculate_control_point(point(), point(), point(), atom(), options()) ::
          {number(), number()}
  defp calculate_control_point(curr, prev, next, direction, options) do
    smoothing = Keyword.get(options, :line_smoothing)

    {length, angle} = calculate_line(prev, next)

    angle = if direction == :right, do: angle + :math.pi(), else: angle
    length = length * smoothing

    {
      curr.x + :math.cos(angle) * length,
      curr.y + :math.sin(angle) * length
    }
  end

  @spec calculate_line(point(), point()) :: {number(), number()}
  defp calculate_line(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    length_x = x2 - x1
    length_y = y2 - y1

    {
      :math.sqrt(:math.pow(length_x, 2) + :math.pow(length_y, 2)),
      :math.atan2(length_y, length_x)
    }
  end

  # Helper functions

  @spec default_options(options()) :: options()
  defp default_options(options) do
    Keyword.merge(@default_options, options)
  end

  @spec tuple_to_string({number(), number()}) :: String.t()
  defp tuple_to_string({x, y}) do
    "#{format_float(x)},#{format_float(y)}"
  end

  @spec format_float(float()) :: float()
  defp format_float(float) when is_float(float) do
    Float.round(float, 3)
  end
end