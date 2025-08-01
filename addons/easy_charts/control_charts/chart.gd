@icon("res://addons/easy_charts/utilities/icons/linechart.svg")
extends PanelContainer
class_name Chart

@onready var _canvas: Canvas = $Canvas
@onready var plot_box: PlotBox = %PlotBox
@onready var grid_box: GridBox = %GridBox
@onready var functions_box: Control = %FunctionsBox
@onready var function_legend: FunctionLegend = %FunctionLegend

@onready var _tooltip: DataTooltip = %Tooltip
var _function_of_tooltip: Function = null

var functions: Array = []
var x: Array = []
var y: Array = []

var x_labels_function: Callable = Callable()
var y_labels_function: Callable = Callable()

var x_domain: ChartAxisDomain = null
var y_domain: ChartAxisDomain = null

var chart_properties: ChartProperties = null

###########

func _ready() -> void:
	if theme == null:
		theme = Theme.new()

func plot(functions: Array[Function], properties: ChartProperties = ChartProperties.new()) -> void:
	self.functions = functions
	self.chart_properties = properties

	theme.set("default_font", self.chart_properties.font)
	_canvas.prepare_canvas(self.chart_properties)
	plot_box.chart_properties = self.chart_properties
	function_legend.chart_properties = self.chart_properties

	load_functions(functions)

func load_functions(functions: Array[Function]) -> void:
	self.x = []
	self.y = []

	function_legend.clear()

	# Remove existing function_plotters
	for function_plotter in functions_box.get_children():
		functions_box.remove_child(function_plotter)
		function_plotter.queue_free()

	for function in functions:
		# Load x and y values
		self.x.append(function.__x)
		self.y.append(function.__y)

		# Create FunctionPlotter
		var function_plotter := FunctionPlotter.create_for_function(self, function)
		function_plotter.point_entered.connect(_show_tooltip)
		function_plotter.point_exited.connect(_hide_tooltip)
		functions_box.add_child(function_plotter)

		# Create legend
		match function.get_type():
			Function.Type.PIE:
				for i in function.__x.size():
					var interp_color: Color = function.get_gradient().sample(float(i) / float(function.__x.size()))
					function_legend.add_label(function.get_type(), interp_color, Function.Marker.NONE, function.__y[i])
			_:
				function_legend.add_function(function)

	_draw()

## Returns all functions of a specific type that are part of this chart.
func get_functions_by_type(type: Function.Type) -> Array[Function]:
	return functions.filter(func(function: Function) -> bool:
		return function.get_type() == type
	)

## Returns true, if the x tick labels should be rendered centered between
## tick lines. This is the case if there are multiple bar charts AND
## the x values are discrete.
func are_x_tick_labels_centered() -> bool:
	return get_functions_by_type(Function.Type.BAR).size() > 1 && \
			x_domain.is_discrete

func _draw() -> void:
	if (x.size() == 0) or (y.size() == 0) or (x.size() == 1 and x[0].is_empty()) or (y.size() == 1 and y[0].is_empty()):
		printerr("Cannot plot an empty function!")
		return

	var is_x_fixed: bool = x_domain != null && x_domain.fixed
	var is_y_fixed: bool = y_domain != null && y_domain.fixed

	# GridBox
	if not is_x_fixed or not is_y_fixed :
		if chart_properties.max_samples > 0 :
			var _x: Array = []
			var _y: Array = []

			_x.resize(x.size())
			_y.resize(y.size())

			for i in x.size():
				if not is_x_fixed:
					_x[i] = x[i].slice(max(0, x[i].size() - chart_properties.max_samples), x[i].size())
				if not is_y_fixed:
					_y[i] = y[i].slice(max(0, y[i].size() - chart_properties.max_samples), y[i].size())

			if not is_x_fixed:
				x_domain = ChartAxisDomain.from_values(_x, chart_properties.smooth_domain)
			if not is_y_fixed:
				y_domain = ChartAxisDomain.from_values(_y, chart_properties.smooth_domain)
		else:
			if not is_x_fixed:
				x_domain = ChartAxisDomain.from_values(x, chart_properties.smooth_domain)
			if not is_y_fixed:
				y_domain = ChartAxisDomain.from_values(y, chart_properties.smooth_domain)
	
	if !x_domain.is_discrete:
		x_domain.set_tick_count(chart_properties.x_scale)

	if x_labels_function:
		x_domain.labels_function = x_labels_function

	if !y_domain.is_discrete:
		y_domain.set_tick_count(chart_properties.y_scale)

	if y_labels_function:
		y_domain.labels_function = y_labels_function

	# Update values for the PlotBox in order to propagate them to the children
	update_plotbox(x_domain, y_domain, x_labels_function, y_labels_function)

	# Update GridBox
	grid_box.x_labels_centered = are_x_tick_labels_centered()
	update_gridbox(x_domain, y_domain, x_labels_function, y_labels_function)

	# Update each FunctionPlotter in FunctionsBox
	for function_plotter in functions_box.get_children():
		if function_plotter is FunctionPlotter:
			function_plotter.visible = function_plotter.function.get_visibility()
			if function_plotter.function.get_visibility():
				function_plotter.update_values(x_domain, y_domain)

func set_x_domain(lb: Variant, ub: Variant) -> void:
	x_domain = ChartAxisDomain.from_bounds(lb, ub)

func set_y_domain(lb: Variant, ub: Variant) -> void:
	y_domain = ChartAxisDomain.from_bounds(lb, ub)

func update_plotbox(x_domain: ChartAxisDomain, y_domain: ChartAxisDomain, x_labels_function: Callable, y_labels_function: Callable) -> void:
	plot_box.box_margins = calculate_plotbox_margins(x_domain, y_domain, y_labels_function)

func update_gridbox(x_domain: ChartAxisDomain, y_domain: ChartAxisDomain, x_labels_function: Callable, y_labels_function: Callable) -> void:
	grid_box.set_domains(x_domain, y_domain)
	grid_box.set_labels_functions(x_labels_function, y_labels_function)
	grid_box.queue_redraw()

func calculate_plotbox_margins(x_domain: ChartAxisDomain, y_domain: ChartAxisDomain, y_labels_function: Callable) -> Vector2:
	var plotbox_margins: Vector2 = Vector2(
		chart_properties.x_tick_size,
		chart_properties.y_tick_size
	)

	if chart_properties.show_tick_labels:
		var x_ticklabel_size: Vector2
		var y_ticklabel_size: Vector2

		var y_max_formatted: String = y_labels_function.call(y_domain.ub) if not y_labels_function.is_null() else \
			ECUtilities._format_value(y_domain.ub, y_domain.has_decimals)
		if y_domain.lb < 0: # negative number
			var y_min_formatted: String = y_labels_function.call(y_domain.ub) if not y_labels_function.is_null() else \
				ECUtilities._format_value(y_domain.lb, y_domain.has_decimals)
			if y_min_formatted.length() >= y_max_formatted.length():
				y_ticklabel_size = chart_properties.get_string_size(y_min_formatted)
			else:
				y_ticklabel_size = chart_properties.get_string_size(y_max_formatted)
		else:
			y_ticklabel_size = chart_properties.get_string_size(y_max_formatted)

		plotbox_margins.x += y_ticklabel_size.x + chart_properties.x_ticklabel_space
		plotbox_margins.y += ThemeDB.fallback_font_size + chart_properties.y_ticklabel_space

	return plotbox_margins

func _on_plot_box_resized() -> void:
	grid_box.queue_redraw()
	for function in functions_box.get_children():
		function.queue_redraw()

func _show_tooltip(point: Point, function: Function, options: Dictionary = {}) -> void:
	var x_value: String = x_domain.get_tick_label(point.value.x, x_labels_function)
	var y_value: String = y_domain.get_tick_label(point.value.y, y_labels_function)
	var color: Color = function.get_color() if function.get_type() != Function.Type.PIE \
		else function.get_gradient().sample(options.interpolation_index)
	_tooltip.show()
	_tooltip.update_values(x_value, y_value, function.name, color)
	_tooltip.update_position(point.position)
	_function_of_tooltip = function

func _hide_tooltip(point: Point, function: Function) -> void:
	if function != _function_of_tooltip:
		return

	_tooltip.hide()

func _on_function_legend_function_clicked(function: Function) -> void:
	function.toggle_visibility()
	queue_redraw()
