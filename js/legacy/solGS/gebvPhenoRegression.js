/** 
* breeding values vs phenotypic deviation 
* plotting using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


jQuery(document).ready( function() {

    var popDetails  = solGS.getPopulationDetails();
    var traitId     = jQuery("#trait_id").val();
    
    var args = {
	'trait_id'       : traitId,
	'training_pop_id': popDetails.training_pop_id,
	'combo_pops_id'  : popDetails.combo_pops_id
    };
   
    checkDataExists(args);   
 
});


function checkDataExists (args) {
    
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: args,
        url: '/heritability/check/data/',
        success: function(response) {
            if(response.exists === 'yes') {
                getRegressionData(args);

            } else {                
                calculateVarianceComponents(args);
            }
        },
        error: function(response) {                    
            // alert('there is error in checking the dataset for heritability analysis.');     
        }  
    });
  
}


function calculateVarianceComponents (args) {
 
    var gebvUrl = window.location.pathname; //'/solgs/trait/' + traitId  + '/population/' + populationId;
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'source' : 'heritability'},
        url: gebvUrl,
        success: function(response) {
            if(response.status === 'success') {
                getRegressionData(args);
            } else {
              jQuery("#heritability_message").html('Error occured estimating breeding values for this trait.');   
            }
        },
        error: function(response) { 
            jQuery("#heritability_message").html('Error occured estimating breeding values for this trait.');            
        }  
    });
}


function getRegressionData (args) { 
       
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: args,
        url: '/heritability/regression/data/',
        success: function(response) {
            if(response.status === 'success') {
                var regressionData = {
                    'breeding_values'     : response.gebv_data,
                    'phenotype_values'    : response.pheno_data,
                    'phenotype_deviations': response.pheno_deviations,
                    'heritability'        : response.heritability  
                };
                    
                jQuery("#heritability_message").empty();
                plotRegressionData(regressionData);
            }
        },
        error: function(response) {                    
          jQuery("#heritability_message").html('Error occured getting regression data.');
        }
    });
}


function plotRegressionData(regressionData){
  
    var breedingValues      = regressionData.breeding_values;
    var phenotypeDeviations = regressionData.phenotype_deviations;
    var heritability        = regressionData.heritability;
    var phenotypeValues     = regressionData.phenotype_values;

     var phenoRawValues = phenotypeValues.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

    var phenoXValues = phenotypeDeviations.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

     var breedingYValues = breedingValues.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });
  
    var lsData      = [];
    var scatterData = [];
   
    phenotypeDeviations.map( function (pv) {
      
        var sD = [];
        var lD = []; 
        jQuery.each(breedingValues, function(i, gv) {
            
            if ( pv[0] === gv[0] ) {
         
                sD.push({'name' : gv[0], 'gebv' : gv[1], 'pheno_dev': pv[1]} );
                
                var ptY = parseFloat(gv[1]);
                var ptX = parseFloat(pv[1]);
                lD.push(ptX, ptY);
                
                return false;
            }
            
        });
        lsData.push(lD);
        scatterData.push(sD);       
    });
     
    var height = 300;
    var width  = 500;
    var pad    = {left:20, top:20, right:20, bottom: 20}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    var svg = d3.select("#gebv_pheno_regression_canvas")
        .append("svg")
        .attr("width", totalW)
        .attr("height", totalH);

    var regressionPlot = svg.append("g")
        .attr("id", "#gebv_pheno_regression_plot")
        .attr("transform", "translate(" + (pad.left - 5) + "," + (pad.top - 5) + ")");
   
    var phenoMin = d3.min(phenoXValues);
    var phenoMax = d3.max(phenoXValues); 
    
    var xLimits = d3.max([Math.abs(d3.min(phenoXValues)), d3.max(phenoXValues)]);
    var yLimits = d3.max([Math.abs(d3.min(breedingYValues)), d3.max(breedingYValues)]);
    
    var xAxisScale = d3.scale.linear()
        .domain([0, xLimits])
        .range([0, width/2]);
    
    var xAxisLabel = d3.scale.linear()
        .domain([(-1 * xLimits), xLimits])
        .range([0, width]);

    var yAxisScale = d3.scale.linear()
        .domain([0, yLimits])
        .range([0, (height/2)]);

    var xAxis = d3.svg.axis()
        .scale(xAxisLabel)
        .tickSize(3)
        .orient("bottom");
          
    var yAxisLabel = d3.scale.linear()
        .domain([(-1 * yLimits), yLimits])
        .range([height, 0]);
    
   var yAxis = d3.svg.axis()
        .scale(yAxisLabel)
        .tickSize(3)
        .orient("left");

    var xAxisMid = 0.5 * (totalH); 
    var yAxisMid = 0.5 * (totalW);
 
    regressionPlot.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(" + pad.left + "," + xAxisMid +")")
        .call(xAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", 10)
        .attr("dy", ".1em")         
        .attr("transform", "rotate(90)")
        .attr("fill", "green")
        .style({"text-anchor":"start", "fill": "#86B404"});
       
    regressionPlot.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(" + yAxisMid +  "," + pad.top  + ")")
        .call(yAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "green")
        .style("fill", "#86B404");

    regressionPlot.append("g")
        .attr("id", "x_axis_label")
        .append("text")
        .text("Phenotype deviations (X)")
        .attr("y", (pad.top + (height/2)) + 50)
        .attr("x", (width - 110))
        .attr("font-size", 10)
        .style("fill", "#86B404")

    regressionPlot.append("g")
        .attr("id", "y_axis_label")
        .append("text")
        .text("Breeding values (Y)")
        .attr("y", (pad.top -  10))
        .attr("x", ((width/2) - 80))
        .attr("font-size", 10)
        .style("fill", "#86B404")

    regressionPlot.append("g")
        .selectAll("circle")
        .data(scatterData)
        .enter()
        .append("circle")
        .attr("fill", "#9A2EFE")
        .attr("r", 3)
        .attr("cx", function(d) {
            var xVal = d[0].pheno_dev;
           
            if (xVal >= 0) {
                return  (pad.left + (width/2)) + xAxisScale(xVal);
            } else {   
                return (pad.left + (width/2)) - (-1 * xAxisScale(xVal));
           }
        })
        .attr("cy", function(d) {             
            var yVal = d[0].gebv;
            
            if (yVal >= 0) {
                return ( pad.top + (height/2)) - yAxisScale(yVal);
            } else {
                return (pad.top + (height/2)) +  (-1 * yAxisScale(yVal));                  
            }
        })        
        .on("mouseover", function(d) {
            d3.select(this)
                .attr("r", 5)
                .style("fill", "#86B404")
            regressionPlot.append("text")
                .attr("id", "dLabel")
                .style("fill", "#86B404")              
                .text( d[0].name + "(" + d[0].pheno_dev + "," + d[0].gebv + ")")
                .attr("x", pad.left + 1)
                .attr("y", pad.top + 80);
        })
        .on("mouseout", function(d) { 
            d3.select(this)
                .attr("r", 3)
                .style("fill", "#9A2EFE")
            d3.selectAll("text#dLabel").remove();            
        });
  
    var line = ss.linear_regression()
        .data(lsData)
        .line(); 
   
    var lineParams = ss.linear_regression()
        .data(lsData)
     
    var alpha = lineParams.b();
    alpha     =  Math.round(alpha*100) / 100;
    
    var beta = lineParams.m();
    beta     = Math.round(beta*100) / 100;
    
    var sign; 
    if (beta > 0) {
        sign = ' + ';
    } else {
        sign = ' - ';
    };

    var equation = 'y = ' + alpha  + sign  +  beta + 'x'; 

    var rq = ss.r_squared(lsData, line);
    rq     = Math.round(rq*100) / 100;
    rq     = 'R-squared = ' + rq;

    var lsLine = d3.svg.line()
        .x(function(d) {
            if (d[0] >= 0) {
                return  (pad.left + (width/2)) + xAxisScale(d[0]);
            } else {   
                return (pad.left + (width/2)) - (-1 * xAxisScale(d[0]));
            }})
        .y(function(d) { 
            if (d[1] >= 0) {
                return ( pad.top + (height/2)) - yAxisScale(d[1]);
            } else {
                return  (pad.top + (height/2)) +  (-1 * yAxisScale(d[1]));                  
            }});
     
    
   
    var lsPoints = [];          
    jQuery.each(phenotypeDeviations, function (i, x)  {
       
        var  y = line(parseFloat(x[1])); 
        lsPoints.push([x[1], y]); 
   
    });
      
    regressionPlot.append("svg:path")
        .attr("d", lsLine(lsPoints))
        .attr('stroke', '#86B404')
        .attr('stroke-width', 2)
        .attr('fill', 'none');

     regressionPlot.append("g")
        .attr("id", "equation")
        .append("text")
        .text(equation)
        .attr("x", 20)
        .attr("y", 30)
        .style("fill", "#86B404")
        .style("font-weight", "bold");  
    
     regressionPlot.append("g")
        .attr("id", "rsquare")
        .append("text")
        .text(rq)
        .attr("x", 20)
        .attr("y", 50)
        .style("fill", "#86B404")
        .style("font-weight", "bold");  
   
}









