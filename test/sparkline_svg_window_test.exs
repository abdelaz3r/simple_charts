defmodule SparklineSvgWindowTest do
  use ExUnit.Case, async: true

  alias SparklineSvg.Datapoint

  test "set_x_window/2 with too much data" do
    {:ok, sparkline} =
      [2, 2, 2]
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(min: 1)
      |> SparklineSvg.dry_run()

    assert sparkline.datapoints == [
             %Datapoint{source: {1, 2}, computed: {2.0, 25.0}},
             %Datapoint{source: {2, 2}, computed: {198.0, 25.0}}
           ]

    {:ok, sparkline} =
      [2, 2, 2]
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(max: 1)
      |> SparklineSvg.dry_run()

    assert sparkline.datapoints == [
             %Datapoint{source: {0, 2}, computed: {2.0, 25.0}},
             %Datapoint{source: {1, 2}, computed: {198.0, 25.0}}
           ]

    {:ok, sparkline} =
      [2, 2, 2, 2, 2, 2, 2]
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(min: 1, max: 2)
      |> SparklineSvg.dry_run()

    assert sparkline.datapoints == [
             %Datapoint{source: {1, 2}, computed: {2.0, 25.0}},
             %Datapoint{source: {2, 2}, computed: {198.0, 25.0}}
           ]
  end

  test "set_x_window/2 with {x, y} data" do
    {:ok, sparkline} =
      [{1, 2}, {2, 2}, {3, 2}]
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(min: 2)
      |> SparklineSvg.dry_run()

    assert sparkline.datapoints == [
             %Datapoint{source: {2, 2}, computed: {2.0, 25.0}},
             %Datapoint{source: {3, 2}, computed: {198.0, 25.0}}
           ]
  end

  test "set_x_window/2 with hole on left" do
    {:ok, sparkline} =
      [2, 2]
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(min: -1)
      |> SparklineSvg.dry_run()

    assert sparkline.datapoints == [
             %Datapoint{source: {0, 2}, computed: {100.0, 25.0}},
             %Datapoint{source: {1, 2}, computed: {198.0, 25.0}}
           ]
  end

  test "set_x_window/2 with hole on right" do
    {:ok, sparkline} =
      [2, 2]
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(max: 2)
      |> SparklineSvg.dry_run()

    assert sparkline.datapoints == [
             %Datapoint{source: {0, 2}, computed: {2.0, 25.0}},
             %Datapoint{source: {1, 2}, computed: {100.0, 25.0}}
           ]
  end

  test "set_x_window/2 with non-number window" do
    now = DateTime.utc_now()
    now_plus_one = DateTime.add(now, 1)

    {:ok, sparkline} =
      [{now, 1}, {now_plus_one, 2}]
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(min: DateTime.add(now, -1))
      |> SparklineSvg.dry_run()

    assert sparkline.datapoints == [
             %Datapoint{source: {now, 1}, computed: {100.0, 48.0}},
             %Datapoint{source: {now_plus_one, 2}, computed: {198.0, 2.0}}
           ]
  end

  test "set_x_window/2 with mixed data type" do
    now = DateTime.utc_now()

    resp =
      [{now, 1}, {DateTime.add(now, 1), 2}]
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(min: Time.utc_now())
      |> SparklineSvg.dry_run()

    assert resp == {:error, :mixed_datapoints_types}
  end

  test "set_x_window/2 out-of-bound" do
    {:ok, sparkline} =
      1..5
      |> SparklineSvg.new()
      |> SparklineSvg.set_x_window(min: -5, max: -1)
      |> SparklineSvg.dry_run()

    assert sparkline.datapoints == []
  end
end
