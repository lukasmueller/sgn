
import '../../legacy/jquery.js';

export function init(main_div){
  if (!(main_div instanceof HTMLElement)){
    main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
  }  


<div style="width:300px">
Choose a dataset: 
<span style="width:240px" id="mixed_model_dataset_select">
</span>
<button class="btn btn-main" id="mixed_model_analysis_prepare_button">Go!</button>
</div>

<br />
<br />
Choose dependent variable:<br />
<div id="dependent_variable">
</div>

<div id="trait_histogram">
[Histogram]
</div>



<div class="wrapper" style="position:absolute;width:100%">
  Available factors
  
  <div id="factors" style="position:absolute;text-align:left;width:300px;z-index:3"> <!-- class="ui-widget-content" -->
    Available factors
  </div>
  
  <div style="position:absolute;left:320px;top:0px;height:200px;width:600px;border-style:dotted;border-width:1px" id="fixed_factors">
    Fixed factors
  </div>

  <div id="fixed_factors_collection" style="position:absolute;top:220px;left:320px;width:600px;height:200px;border-style:dotted;border-width:2px">
    <div id="fixed_factors_interaction" style="position:relative;width:500px;height:140px;border-style:dotted;margin:30px;border-width:1px">
      Fixed factors with interaction
    </div>
    <button style="position:relative" id="add_interaction_factor_button">+</button>
  </div>

  <div id="random_factors" style="position:absolute;left:320px;width:600px;top:400px;height:200px;border-style:dotted;border-width:1px">
    Random factors
  </div>

</div>


<br />
<div id="tempfile" style="display:none" >
</div>

<button style="position:relative;top:700px;" id="run_mixed_model_button" class="btn btn-main">Go!</button>

<div id="mixed_models_results_div">
</div>


  get_select_box("datasets", "mixed_model_dataset_select", {});
  
     jQuery('#mixed_model_analysis_prepare_button').click( function() { 
       var dataset_id=jQuery('#available_datasets').val();
       jQuery.ajax({
         url: '/ajax/mixedmodels/prepare',
         data: { 'dataset_id' : dataset_id },
         success: function(r) { 
           if (r.error) { 
             alert(r.error);
           }
           else { 
             jQuery('#dependent_variable').html(r.dependent_variable);
             var html = "";
             alert(JSON.stringify(r.factors));
             for (var n=0; n<r.factors.length; n++) { 
                html += "<div style=\"border-style:solid;border-radius:8px;width:200px;height:20;border-color:blue;margin:4px;text-align:left\" id=\"factor_"+n+"\" class=\"container\">"+r.factors[n]+"</div>";
             }
             jQuery('#factors').html(html);
             alert(html);
	     for (var n=0; n<r.factors.length; n++) { 
	       jQuery('#factor_'+n).draggable({ helper:"clone",revert:"invalid"} );
             }

             jQuery('#tempfile').html(r.tempfile);
           }
	   jQuery('#fixed_factors').droppable( {drop: function( event, ui ) {
					       $( this )
					       .addClass( "ui-state-highlight" )
					       .find( "p" )
					       .html( "Dropped!" );
					       var droppable = $(this);
					       var draggable = ui.draggable;
					       // Move draggable into droppable
					       var clone = draggable.clone();
                                               clone.draggable({ revert: "invalid", helper:"clone" });
					       clone.css("z-index",3);
                                               if (!isCloned(clone)) { 
					          setClonedTagProperties(clone);
                                               }
                                              
					       clone.appendTo(droppable);

                                               }});

 	   jQuery('#fixed_factors_interaction').droppable( {drop: function( event, ui ) {
					       $( this )
					       .addClass( "ui-state-highlight" )
					       .find( "p" )
					       .html( "Dropped!" );
                                               var droppable = $(this);
					       var draggable = ui.draggable;
					       // Move draggable into droppable
					       var clone = draggable.clone();
                                               clone.draggable({ revert: "invalid", helper:"clone" });
					       clone.css("z-index",3);
                                               if (!isCloned(clone)) { 
					          setClonedTagProperties(clone);
                                               }
					       
					       clone.appendTo(droppable);
                   			       }});

	   jQuery('#random_factors').droppable( {drop: function( event, ui ) {
					       $( this )
					       .addClass( "ui-state-highlight" )
					       .find( "p" )
					       .html( "Dropped!" );
					       var droppable = $(this);
					       var draggable = ui.draggable;
					       // Move draggable into droppable
					       var clone = draggable.clone();
                                               clone.draggable({ revert: "invalid", helper:"clone" });
					       clone.css("z-index",3);
                                               if (!isCloned(clone)) { 
					          setClonedTagProperties(clone);
                                               }
                                   
					       clone.appendTo(droppable);
                                               					       }});

        },
        error: function(r) { 
          alert("ERROR!!!!!");
        }
     });
   });


   jQuery('#add_interaction_factor_button').click( function(e) { 
      alert("HELLO!");
      var div = '<div id="blabla" style="width:300;height:200">Interaction</div>';					       
      jQuery('#add_interaction_factor_button').before(div);
   });

   function isCloned(e) { 
     if (e.text().includes('X')) { 
        alert(e.text()+' isCloned!');
	return true;
     }
     alert(e.text()+ " Is not cloned!");
      return false;
   }

   function setClonedTagProperties(e) { 
					       alert("Bla!");
     e.id = e.html()+'C';
     e.html('<span id="'+e.id+'_remove" onclick="this.parentNode.parentNode.removeChild(this.parentNode); return false;">X</a></span> '+e.html());
     jQuery('#'+e.id+'_remove').click( function(e) { alert('removing'+e.id); jQuery('#'+e.id).remove(); });
     alert("Current ID = "+e.id);
   }


   jQuery('#dependent_variable').on('change', '#dependent_variable_select', function() { 
      // alert("click!");
      var tempfile = jQuery('#tempfile').html();
      var trait = jQuery('#dependent_variable_select').val();
      jQuery.ajax( {
         url: '/ajax/mixedmodels/grabdata',
         data: { 'file' : tempfile },
         success: function(r)  { 
         //alert("data grabbed "+JSON.stringify(r.data));
           var v = {
             "$schema": "https://vega.github.io/schema/vega-lite/v2.json",
             "width": 200,
             "height": 100,
             "padding": 5,
             "data": { 'values': r.data },
             "mark": "bar",
             "encoding": {
             "x": {
               "bin": true,
               "field": trait,
               "type": "quantitative"
             },
             "y": {
               "aggregate": "count",
               "type": "quantitative"
             }
            }
           }; 
           
  //alert("embedding"+ JSON.stringify(v));
           vegaEmbed("#trait_histogram", v);
           //alert("done");
         },
       
       
       error: function(e) { alert('error!'); }
     });
   });

   jQuery('#run_mixed_model_button').click( function() { 
      var dependent_variable = jQuery('#dependent_variable_select').val();
      var fixed_factors = jQuery('#fixed_factors_select').val();
      var random_factors = jQuery('#random_factors_select').val();
      var fixed_factors_interaction = jQuery('#fixed_factors_interaction').val();
      var random_factors_random_slope = jQuery('#random_factor_random_slope').val();
      var tempfile = jQuery('#tempfile').html();

      // alert('Dependent variable: '+ dependent_variable +' Fixed Factors: '+ fixed_factors +' Random Factors: '+ random_factors +' Tempfile: '+tempfile);
      // alert(JSON.stringify(fixed_factors));
      jQuery.ajax( {
        url: '/ajax/mixedmodels/run',
        data: { 
          'dependent_variable': dependent_variable, 
          'fixed_factors': fixed_factors.join(","), 
          'fixed_factors_interaction' : fixed_factors_interaction,
          'random_factors': random_factors.join(","), 
          'random_factors_random_slope': random_factors_random_slope,
          'tempfile' : tempfile 
        },
        success: function(r) { 
          if (r.error) { alert(r.error);}
          else{ 
            // alert('success...');
            jQuery('#mixed_models_results_div').html('<pre>' + r.html + '</pre>');
          }
        },
        error: function(r) { 
          alert(r);
        }
      });      
    });

  });

