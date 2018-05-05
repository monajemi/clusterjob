// Heavily influenced by Mike Bostock's Scatter Matrix example
// http://mbostock.github.io/d3/talk/20111116/iris-splom.html
//

ScatterMatrix = function(url, data, dom_id, el) {
  this.__url = url;
  if (data === undefined || data === null) { this.__data = undefined; }
  else { this.__data = d3.csv.parse(data); }
  this.__cell_size = 200;
  this.__circle_size = 2;
  if (dom_id === undefined) { this.__dom_id = 'body'; }
  else { this.__dom_id = "#"+dom_id; }
  if (el)
    this.__dom_id = el;
};

ScatterMatrix.prototype.onData = function(cb) {
  if (this.__data) { cb(); return; }
  var self = this;

  function type(row) {
    
    numeric_variables = d3.keys(row).filter(function(d) { return (d != "net" && d != "dataset" && d != ""); });

    out = {};
    out["net"] = row["net"];
    out["dataset"] = row["dataset"];
    numeric_variables.forEach(function(d) {
      out[d] = +row[d];
    });

    return  out;
  }

  d3.csv(self.__url, type, function(data) {
    self.__data = data;
    cb();
  });
};

ScatterMatrix.prototype._numeric_to_str_key = function(k) { return k+'_'; };
ScatterMatrix.prototype._is_numeric_str_key = function(k) { return k[k.length-1] === '_'; };
ScatterMatrix.prototype._str_to_numeric_key = function(k) {
  if (this._is_numeric_str_key(k)) { return k.slice(0, k.length-1); }
  return null;
};

ScatterMatrix.prototype.render = function () {
  var self = this;

  var container = d3.select(this.__dom_id).append('div')
                    .attr('class', 'scatter-matrix-container');
  var control = container.append('div')
                         .attr('class', 'scatter-matrix-control');
  var svg = container.append('svg')
                     .attr('class', 'scatter-matrix-svg');

  this.onData(function() {
    var data = self.__data;

    self.__numeric_variables = d3.keys(data[0]).filter(function(d) { return (d != "net" & d != "dataset"); })

    var nets = d3.set(data.map(function(d) { return d.net; })).values();
    
    var datasets = d3.set(data.map(function(d) { return d.dataset; })).values();
    
    var varX, varY, varC;

    // Add controls on the left

    var size_control = control.append('div').attr('class', 'scatter-matrix-size-control');
    var variable_text = control.append('div').attr('class', 'scatter-matrix-text');
    var variable_control = control.append('div').attr('class', 'scatter-matrix-variable-control');
    var variable_text_2 = control.append('div').attr('class', 'scatter-matrix-text');
    
    size_a = size_control.append('h2').text('Change plot size: ');
    size_a.append('a')
          .attr('href', 'javascript:void(0);')
          .html('-')
          .on('click', function() {
            self.__cell_size *= 0.9;
            self.__draw(self.__cell_size,  self.__circle_size, svg, nets, datasets, varX, varY, varC);
          })
    size_a.append('span').html('&nbsp;');
    size_a.append('a')
          .attr('href', 'javascript:void(0);')
          .html('+')
          .on('click', function() {
            self.__cell_size *= 1.1;
            self.__draw(self.__cell_size, self.__circle_size, svg, nets, datasets, varX, varY, varC);
          });
    
    size_a = size_control.append('h2').text('Change circle size: ');
    size_a.append('a')
          .attr('href', 'javascript:void(0);')
          .html('-')
          .on('click', function() {
            self.__circle_size *= 0.8;
            self.__draw(self.__cell_size, self.__circle_size, svg, nets, datasets, varX, varY, varC);
          })
    size_a.append('span').html('&nbsp;');
    size_a.append('a')
          .attr('href', 'javascript:void(0);')
          .html('+')
          .on('click', function() {
            self.__circle_size *= 1.2;
            self.__draw(self.__cell_size, self.__circle_size, svg, nets, datasets, varX, varY, varC);
          });

    variable_text.append('h2')
        .text('Choose control parameters Z or observables W: ')
        
    var variable_li_Y =
      variable_control
        .append('ul')
        .append('h2').text('V1: ')
        .append('p')
        .selectAll('li')
        .data(self.__numeric_variables)
        .enter().append('li');

    variable_li_Y.append('input')
              .attr('type', 'radio')
              .attr('name',self.__dom_id+'radioY')
              .on('click', function(d, i) {
                varY = d;
                if (varX && varY)
                  self.__draw(self.__cell_size, self.__circle_size, svg, nets, datasets, varX, varY, varC);
              });
    variable_li_Y.append('label')
              .html(function(d) { return " "+d; });

    var variable_li_X =
      variable_control
        .append('ul')
        .append('h2').text('V2: ')
        .append('p')
        .selectAll('li')
        .data(self.__numeric_variables)
        .enter().append('li');
  
    variable_li_X.append('input')
                .attr('type', 'radio')
                .attr('name',self.__dom_id+'radioX')
                .on('click', function(d, i) {
                varX = d;
                if (varX && varY)
                  self.__draw(self.__cell_size, self.__circle_size, svg, nets, datasets, varX, varY, varC);
                });
    variable_li_X.append('label')
                .html(function(d) { return " "+d; });
                
    var variable_li_C =
      variable_control
        .append('ul')
        .append('h2').text('V3: ')
        .append('p')
        .selectAll('li')
        .data(self.__numeric_variables)
        .enter().append('li');

    variable_li_C.append('input')
              .attr('type', 'radio')
              .attr('name',self.__dom_id+'radioC')
              .on('click', function(d, i) {
                varC = d;
                if (varX && varY)
                  self.__draw(self.__cell_size, self.__circle_size, svg, nets, datasets, varX, varY, varC);
              });
    variable_li_C.append('label')
              .html(function(d) { return " "+d; });

    variable_text_2.append('h2')
              .text('For each method X and dataset Y, V1 is plotted against V2 and colored with V3.')
  });
};

ScatterMatrix.prototype.__draw =
  function(cell_size, circle_size, container_el, nets, datasets, varX, varY, varC) {

  var Xs_trait = 'dataset';
  var Ys_trait = 'net';
  var Xs = datasets;
  var Ys = nets;

  var self = this;
  this.onData(function() {
    var data = self.__data;

    container_el.selectAll('*').remove();

    // If no data, don't do anything
    if (data.length == 0) { return; }

    // Size parameters
    var size = cell_size,
        padding = 40,
        x_label_height = 20,
        y_label_height = 80,
        legend_height = 25,
        legend_offset = 105,
        legend_title_offset = -10;

    // Formatting for axis
    var intf = d3.format('d');
    var fltf = d3.format('.f');
    var scif = d3.format('.1e');

    // Root panel
    var svg = container_el.append("svg:svg")
        .attr("width", y_label_height + size * Xs.length + padding)
        .attr("height", size * Ys.length + legend_height + legend_offset)
      .append("svg:g")
        .attr("transform", "translate("+y_label_height+",0)");

    var reshape_axis = function (axis) {
      axis.ticks(4)
          .tickFormat(function (d) {
                        if (Math.abs(+d) > 10000 || (Math.abs(d) < 0.001 && Math.abs(d) != 0)) { return scif(d); }
                        if (parseInt(d) == +d) { return intf(d); }
                        return fltf(d);
                      });
      return axis;
    };

    if (varC) {
      //Append a defs (for definition) element to your SVG
      var defs = svg.append("defs");

      //Append a linearGradient element to the defs and give it a unique id
      var linearGradient = defs.append("linearGradient")
          .attr("id", "linear-gradient");

      //Horizontal gradient
      linearGradient
      .attr("x1", "0%")
      .attr("y1", "0%")
      .attr("x2", "100%")
      .attr("y2", "0%");

      var colors = ["#2c7bb6", "#00a6ca","#00ccbc","#90eb9d","#ffff8c","#f9d057","#f29e2e","#e76818","#d7191c"];
      // var colors = ["#c4dfe6", "#66a5ad", "#07575b", "#003b46"];
      var color_range = d3.range(0, 1, 1.0 / (colors.length - 1));
      color_range.push(1);

      //A color scale
      var colorScale = d3.scale.linear()
          .domain(color_range)
          .range(colors)
          .interpolate(d3.interpolateHcl);

      //Append multiple color stops by using D3's data/enter step
      linearGradient.selectAll("stop") 
      .data( colorScale.range() )                  
      .enter().append("stop")
      .attr("offset", function(d,i) { return i/(colorScale.range().length-1); })
      .attr("stop-color", function(d) { return d; });

      //Color Legend container
      var legendsvg = svg.append("g")
        .attr("class", "legendWrapper")
        .attr("transform", function(d) { return "translate(" + padding/2 + "," + (legend_offset + Ys.length * size) + ")"; });

      //Draw the Rectangle
      legend_width = Xs.length * size - padding
      legendsvg.append("rect")
        .attr("class", "legendRect")
        .attr("x", 0)
        .attr("y", 0)
        .attr("width", legend_width)
        .attr("height", legend_height)
        .style("fill", "none");

      //Append title
      legendsvg.append("text")
        .attr("class", "legendTitle")
        .attr("x", legend_width/2)
        .attr("y", legend_title_offset)
        .attr("text-anchor", "middle")
        .text(varC);

      //Fill the legend rectangle
      svg.select(".legendRect")
        .style("fill", "url(#linear-gradient)")
    }

    // Draw scatter plot
    var cell = svg.selectAll("g.cell")
        .data(cross(Xs, Ys))
      .enter().append("svg:g")
        .attr("class", "cell")
        .attr("transform", function(d) { return "translate(" + d.i * size + "," + d.j * size + ")"; })
        .each(plot);
    
    // Add titles for x variables
    cell.filter(function(d) { return d.j == Ys.length-1; })
        .append("svg:text")
        .attr("x", size/2)
        .attr("y", size+x_label_height)
        .attr("dy", ".75em")
        .attr("text-anchor", "middle")
        .text(function(d) { return d.x; })
      
    cell.filter(function(d) { return d.j == Ys.length-1; })
        .append("svg:text")
        .attr("x", size/2)
        .attr("y", size+x_label_height)
        .attr("dy", "2em")
        .attr("text-anchor", "middle")
        .text(function(d) { return varX; })
    
    // Add titles for y variables
    cell.filter(function(d) { return d.i == 0; }).append("svg:text")
        .attr("x", -size/2)
        .attr("y", -y_label_height)
        .attr("dy", ".71em")
        .attr("text-anchor", "middle")
        .attr("transform", function(d) { return "rotate(-90)"; })
        .text(function(d) { return d.y; })

    cell.filter(function(d) { return d.i == 0; }).append("svg:text")
        .attr("x", -size/2)
        .attr("y", -y_label_height)
        .attr("dy", "2em")
        .attr("text-anchor", "middle")
        .attr("transform", function(d) { return "rotate(-90)"; })
        .text(function(d) { return varY; })

    function plot(p) {

      var data_to_draw = data.filter(function (d) {
        return (d[Xs_trait] == p.x && d[Ys_trait] == p.y);
      });

      var cell = d3.select(this);

      // Frame
      cell.append("svg:rect")
          .attr("class", "frame")
          .attr("x", padding / 2)
          .attr("y", padding / 2)
          .attr("width", size - padding)
          .attr("height", size - padding);

      // Get x and y scales for each numeric variable
      var valueX = function(d) { return d[varX]; };
      domain = [d3.min(data_to_draw, valueX), d3.max(data_to_draw, valueX)];
      range_x = [padding / 2, size - padding / 2];
      var x = d3.scale.linear().domain(domain).range(range_x);

      var valueY = function(d) { return d[varY]; },
      domain = [d3.min(data_to_draw, valueY), d3.max(data_to_draw, valueY)];
      range_y = [padding / 2, size - padding / 2];
      var y = d3.scale.linear().domain(domain).range(range_y.reverse());

      //Needed to map the values of the dataset to the color scale
      if (varC) {
        var varC_value = function(d) { return d[varC]; };
        var colorInterpolate = d3.scale.linear()
            .domain([d3.min(data_to_draw, varC_value), d3.max(data_to_draw, varC_value)])
            .range([0,1]);
      }

      // Scatter plot dots
      cell.selectAll("circle")
          .data(data_to_draw)
        .enter().append("svg:circle")
          .attr("cx", function(d) { return x(d[varX]); })
          .attr("cy", function(d) { return y(d[varY]); })
          .attr("r", circle_size)
          .style("fill", function(d,i){
            if (varC) {
              return colorScale(colorInterpolate(d[varC]))
            } else {
              return "blue";
            }
          });

      // Draw X axis
      var x_axis = reshape_axis(d3.svg.axis())
                    .scale(x)
                    .orient("bottom");
      svg.append("svg:g")
          .attr("class", "x axis")
          .attr("transform", function(d) { return "translate(" + (p.i * size) + "," + ((p.j+1) * size - padding/2) + ")"; })
          .call(x_axis);
      
      // Draw Y axis
      var y_axis = reshape_axis(d3.svg.axis())
                    .scale(y)
                    .orient("left");
      svg.append("svg:g")
          .attr("class", "y axis")
          .attr("transform", function(d) { return "translate(" + (p.i * size + padding/2) + "," + ((p.j) * size ) + ")"; })
          .call(y_axis);
    }

    function cross(a, b) {
      var c = [], n = a.length, m = b.length, i, j;
      for (i = -1; ++i < n;) for (j = -1; ++j < m;) c.push({x: a[i], i: i, y: b[j], j: j});
      return c;
    }
  });
}