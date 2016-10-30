jQuery(document).ready(function() {

    jQuery(document)
        .on('show.bs.collapse', '.panel-collapse', function() {
            var $span = jQuery(this).parents('.panel').find('.panel-heading span.clickable');
            $span.find('i').removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-up');
        })
        .on('hide.bs.collapse', '.panel-collapse', function() {
            var $span = jQuery(this).parents('.panel').find('.panel-heading span.clickable');
            $span.find('i').removeClass('glyphicon-chevron-up').addClass('glyphicon-chevron-down');
        })

    jQuery('#select_trial_for_selection_index').change( // update selection index options when trial selection changes
        function() {

            jQuery('#selection_index').html("");
            jQuery('#trait_table').html("");
            jQuery('#weighted_values_div').html("");
            jQuery('#raw_avgs_div').html("");
            jQuery('#sin_formula_list_select').val("");
            update_formula();

            if (jQuery(this).val() == '') {
                return;
            };

            jQuery('#trait_table_label').html('<a href="/breeders_toolbox/trial/'+jQuery(this).val()+'">'+jQuery('option:selected', this).text()+'</a> Traits and Weights:')

            var trial_id = jQuery(this).val();
            var trial_name = jQuery("option:selected", this).text();

            var data = [
                [jQuery(this).val()]
            ];

            jQuery.ajax({ // get traits phenotyped in trial
                url: '/ajax/breeder/search',
                method: 'POST',
                data: {
                    'categories': ['trials', 'traits'],
                    'data': data,
                    'querytypes': 0
                },
                beforeSend: function() {
                    disable_ui();
                },
                complete: function() {
                    enable_ui();
                },
                success: function(response) {
                    var list = response.list || 0;
                    if (!list) {
                      trait_html = '<option id="select_message" value="" title="No trait measurements found.">No trait measurements found for '+trial_name+'.</option>\n';
                      jQuery('#trait_list').html(trait_html);
                      return;
                    }
                    var trait_ids = [];
                    for (i = 0; i < list.length; i++) {
                        trait_ids.push(list[i][0]);
                    }

                    var synonyms;
                    jQuery.ajax({ // get trait synonyms
                        url: '/ajax/cvterm/get_synonyms',
                        async: false,
                        method: 'POST',
                        data: {
                            'trait_ids': trait_ids
                        },
                        success: function(response) {
                            synonyms = response.synonyms;
                            //console.log("synonyms = " + JSON.stringify(synonyms));
                            trait_html = '<option id="select_message" value="" title="Select a trait">Select a trait</option>\n';
                            for (i = 0; i < list.length; i++) {
                                var trait_id = list[i][0];
                                var trait_name = list[i][1];
                                var parts = trait_name.split("|");
                                var CO_id = parts[1];
                                var synonym = synonyms[trait_id];
                                synonym_fixed = synonym.replace(/"/g, "");
                                var syn_parts = synonym_fixed.split(" ");
                                synonym_fixed = syn_parts[0];
                                trait_html += '<option value="' + trait_id + '" data-synonym="' + synonym_fixed + '" data-CO_id="' + CO_id + '" title="' + parts[0] + '">' + parts[0] + '</a>\n';
                            }

                            jQuery('#trait_list').html(trait_html);

                        },
                        error: function(response) {
                            alert("An error occurred while retrieving synonyms for traits with ids " + trait_ids);
                        }
                    });
                },
                error: function(response) {
                    alert("An error occurred while transforming the list " + list_id);
                }
            });

            jQuery.ajax({ // get plots phenotyped in trial
                url: '/ajax/breeder/search',
                method: 'POST',
                data: {
                    'categories': ['trials', 'plots'],
                    'data': data,
                    'querytypes': 0
                },
                success: function(response) {
                    var plots = response.list || [];
                    //console.log("plots: " + JSON.stringify(plots));
                    var plot_ids = plots.map(function(val) {
                        return val[0]
                    });
                    //console.log("plot ids: " + JSON.stringify(plot_ids));
                    jQuery.ajax({
                        url: '/ajax/breeders/trial/' + data + '/controls_by_plot',
                        data: {
                            'plot_ids': plot_ids
                        },
                        success: function(response) {
                            //console.log('controls:' + JSON.stringify(response));
                            var accessions = response.accessions;
                            var accession_html;
                            if (response.accessions[0].length == 0) {
                                accession_html = '<option value="" title="Select a control">No controls found</a>\n';
                            } else {
                                accession_html = '<option value="" title="Select a control">Select a control</a>\n';
                                for (i = 0; i < response.accessions[0].length; i++) {
                                    accession_html += '<option value="' + accessions[0][i].stock_id + '" title="' + response.accessions[0][i].stock_id + '">' + response.accessions[0][i].accession_name + '</a>\n';
                                }
                            }
                            jQuery('#control_list').html(accession_html);
                            jQuery('#trait_list').focus();
                        },
                        error: function(response) {
                            jQuery('#control_list').html('<option value="" title="Select a control">Error retrieving trial controls</a>');
                        }
                    });
                },
                error: function(response) {
                    jQuery('#control_list').html('<option value="" title="Select a control">Error retrieving trial design</a>');
                }
            });
        });

    jQuery('#trait_list').change( // add selected trait to trait table
        function() {
            var trait_id = jQuery('option:selected', this).val();
            var weight_id = trait_id + '_weight';
            var control_id = trait_id + '_control';
            var trait_name = jQuery('option:selected', this).text();
            var trait_synonym = jQuery('option:selected', this).data("synonym");
            var trait_CO_id = jQuery('option:selected', this).data("co_id");
            var control_html = jQuery('#control_list').html();
            var trait_html = "<tr id='" + trait_id + "_row'><td><a href='/cvterm/" + trait_id + "/view' data-value='" + trait_id + "'>" + trait_name + "</a></td><td><p id='" + trait_id + "_synonym'>" + trait_synonym + "<p></td><td><input type='text' id='" + weight_id + "' class='form-control weight' placeholder='Must be a number (+ or -), default = 1'></input></td><td><select class='form-control' id='" + control_id + "'>" + control_html + "</select></td><td align='center'><a title='Remove' id='" + trait_id + "_remove' href='javascript:remove_trait(" + trait_id + ")'><span class='glyphicon glyphicon-remove'></span></a></td></tr>";
            jQuery('#trait_table').append(trait_html);
            jQuery('#select_message').text('Add another trait');
            jQuery('#select_message').attr('selected', true);
            update_formula();
            jQuery('#' + weight_id).focus();
            jQuery('#' + weight_id).change( //
                function() {
                    update_formula();
                    jQuery('#trait_list').focus();
                });
            jQuery('#' + control_id).change(
                function() {
                    update_formula();
                });
            //jQuery('#calculate_rankings').removeClass('disabled');
        });

    jQuery('#save_sin').click(function() {
      if (jQuery('#trait_table').children().length < 1) {
        document.getElementById('selection_index_error_message').innerHTML = "<center><li class='list-group-item list-group-item-danger'> Formula not saved.<br> At least one trait must be selected before saving a SIN formula.</li></center>";
        jQuery('#selection_index_error_dialog').modal("show");
        return;
      }
        var lo = new CXGN.List();
        var new_name = jQuery('#save_sin_name').val();
        console.log("Saving SIN formula to list named " + new_name);
        var selected_trait_rows = jQuery('#trait_table').children();
        var trait_ids = [],
            trait_names = [],
            weights = [],
            control_ids = [];
        control_names = [];
        jQuery(selected_trait_rows).each(function(index, selected_trait_rows) {
            var trait_id = jQuery('a', this).data("value");
            trait_ids.push(trait_id);
            var trait_name = jQuery('a', this).text();
            trait_names.push(trait_name.trim());
            weights.push(jQuery('#' + trait_id + '_weight').val() || 1); // default = 1
            control_ids.push(jQuery('#' + trait_id + '_control option:selected').val() || '');
            var control_name = jQuery('#' + trait_id + '_control option:selected').text() || '';
            control_names.push(control_name.trim());
        });

        var data = "trait_ids:" + trait_ids.join();
        data += "\ntrait_names:" + trait_names.join();
        data += "\nweights:" + weights.join();
        data += "\ncontrol_ids:" + control_ids.join();
        data += "\ncontrol_names:" + control_names.join();
        console.log("data to save is " + JSON.stringify(data));
        list_id = lo.newList(new_name);
        if (list_id > 0) {
            var elementsAdded = lo.addToList(list_id, data);
        }
        if (elementsAdded) {
            alert("Saved SIN formula to list " + new_name);
        }

    });

    jQuery('#selection_index_error_close_button').click(function() {
        document.getElementById('selection_index_error_message').innerHTML = "";
    });


    jQuery('#calculate_rankings').click(function() {

      if (jQuery('#trait_table').children().length < 1) {
        document.getElementById('selection_index_error_message').innerHTML = "<center><li class='list-group-item list-group-item-danger'> Error.<br> A trial and at least one trait must be selected before calculating rankings.</li></center>";
        jQuery('#selection_index_error_dialog').modal("show");
        return;
      }
        jQuery('#raw_avgs_div').html("");
        jQuery('#weighted_values_div').html("");
        var trial_id = jQuery("#select_trial_for_selection_index option:selected").val();
        var selected_trait_rows = jQuery('#trait_table').children();
        var trait_ids = [],
            column_names = [],
            weighted_column_names = [],
            weights = [],
            controls = [];

        var trial_name = jQuery('#select_trial_for_selection_index option:selected').text();
        column_names.push({
            title: trial_name + " Accession"
        });
        weighted_column_names.push({
            title: trial_name + " Accession"
        });
        jQuery(selected_trait_rows).each(function(index, selected_trait_rows) {
            var trait_id = jQuery('a', this).data("value");
            trait_ids.push(trait_id);
            var trait = jQuery('#' + trait_id + '_synonym').text()
            if (trait == 'None') {
              trait = jQuery('a', this).text();
            }
            var trait_term = "mean "+trait;
            var weight = jQuery('#' + trait_id + '_weight').val() || 1; // default = 1
            weights.push(weight);
            var control = jQuery('#' + trait_id + '_control option:selected').val() || '';
            controls.push(control);
            if (control) {
                trait_term += " relative to " + jQuery('#' + trait_id + '_control option:selected').text();
            }
            column_names.push({
                title: trait_term
            });
            weighted_column_names.push({
                title: weight + " * (" + trait_term + ")"
            });
        });
        weighted_column_names.push({
            title: "SIN"
        }, {
            title: "SIN Rank"
        });
        var allow_missing = jQuery("#allow_missing").is(':checked');

        console.log("trait_ids:" + trait_ids + "\nweights:" + weights + "\ncontrols:" + controls);

        jQuery.ajax({ // get raw averaged and weighted phenotypes from trial
            url: '/ajax/breeder/search/avg_phenotypes',
            method: 'POST',
            data: {
                'trial_id': trial_id,
                'trait_ids': trait_ids,
                'weights': weights,
                'controls': controls,
                'allow_missing': allow_missing
            },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                var raw_avgs = response.raw_avg_values || [];
                var weighted_values = response.weighted_values || [];
                var trial_name = jQuery('#select_trial_for_selection_index option:selected').text();
                build_table(raw_avgs, column_names, trial_name, 'raw_avgs_div');
                build_table(weighted_values, weighted_column_names, trial_name, 'weighted_values_div');
            },
            error: function(response) {
                alert("An error occurred while retrieving average phenotypes");
            }
        });

    });
});

function build_table(data, column_names, trial_name, target_div) {

    var table_id = target_div.replace("div", "table");
    var table_type = target_div.replace("_div", "");
    var table_html = '<br><br><div class="table-responsive" style="margin-top: 10px;"><table id="' + table_id + '" class="table table-hover table-striped table-bordered" width="100%"><caption class="well well-sm" style="caption-side: bottom;margin-top: 10px;"><center> Table description: <i>' + table_type + ' for trial ' + trial_name + '.</i></center></caption></table></div>'
    if (table_type == 'weighted_values') {
        table_html += '<div class="col-sm-12 col-md-12 col-lg-12"><hr><label>Save top ranked accessions to a list: </label><br><br><div class="col-sm-3 col-md-3 col-lg-3" style="display: inline-block"><label>By number:</label>&nbsp;<select class="form-control" id="top_number"></select></div><div class="col-sm-3 col-md-3 col-lg-3" style="display: inline-block"><label>Or percent:</label>&nbsp;<select class="form-control" id="top_percent"></select></div><div class="col-sm-6 col-md-6 col-lg-6"><div style="text-align:right" id="ranking_to_list_menu"></div><div id="top_ranked_names" style="display: none;"></div></div><br><br><br><br><br></div>';
    }

    jQuery('#' + target_div).html(table_html);

    var penultimate_column = column_names.length - 2;
    jQuery('#' + table_id).DataTable({
        dom: 'Bfrtip',
        buttons: ['copy', 'excel', 'csv', 'print'],
        data: data,
        destroy: true,
        paging: true,
        order: [
            [1, 'asc']
        ],
        lengthMenu: [
            [10, 25, 50, -1],
            [10, 25, 50, "All"]
        ],
        columns: column_names,
        order: [
            [penultimate_column, "desc"]
        ],
    });

    if (table_type == 'weighted_values') {

        var table = $('#weighted_values_table').DataTable();
        var name_links = table.column(0).data();
        jQuery("#top_number").append('<option value="">Select a number</option>');
        jQuery("#top_percent").append('<option value="">Select a percent</option>');

        for (i = 1; i <= name_links.length; i++) {
            jQuery("#top_number").append('<option value=' + i + '>' + i + '</option>');
        }
        for (i = 1; i <= 100; i++) {
            jQuery("#top_percent").append('<option value=' + i + '>' + i + '%</option>');
        }

        jQuery('select[id^="top_"]').change( // save top # or % of accession to add to lists
            function() {
                var type = this.id.split("_").pop();
                var number = jQuery('#top_' + type).val();
                var names = [];

                if (type == 'number') {
                    jQuery("#top_percent").val(''); // reset other select
                    for (var i = 0; i < number; i++) { //extract names from anchor tags
                        names.push(name_links[i].match(/<a [^>]+>([^<]+)<\/a>/)[1] + '\n');
                    }
                    //console.log("retrieved top "+number+" names: "+names);
                } else if (type == 'percent') {
                    jQuery("#top_number").val(''); // reset other select
                    var adjusted_number = Math.round((number / 100) * name_links.length);
                    for (var i = 0; i < adjusted_number; i++) { //extract names from anchor tags
                        names.push(name_links[i].match(/<a [^>]+>([^<]+)<\/a>/)[1] + '\n');
                    }
                    //console.log("retrieved top "+number+" percent of names: "+names);
                }
                jQuery('#top_ranked_names').html(names);
                addToListMenu('ranking_to_list_menu', 'top_ranked_names', {
                    listType: 'accessions',
                });
            });

    }
}

function load_sin() { // update traits and selection index when a saved sin formula is picked

    if (!jQuery("#select_trial_for_selection_index option:selected").val()) {
      document.getElementById('selection_index_error_message').innerHTML = "<center><li class='list-group-item list-group-item-danger'> Error.<br> A trial must be selected before loading a SIN formula.</li></center>";
      jQuery('#selection_index_error_dialog').modal("show");
      return;
    }

    //retrieve contents of list:
    var sin_list_id = jQuery('#sin_formula_list_select').val();
    if (!sin_list_id) {
        update_formula();
        return;
    }
    var lo = new CXGN.List();

    var list_data = lo.getListData(sin_list_id);
    var sin_data = list_data.elements;
    var trait_ids = [];
    var trait_names = [];
    var weights = [];
    var control_ids = [];
    var control_names = [];

    for (i = 0; i < sin_data.length; i++) {
        var array = sin_data[i];
        array.shift();
        var string = array.shift();
        var parts = string.split(":");
        var values = parts[1];
        switch (parts[0]) {
            case 'trait_ids':
                trait_ids = values.split(",");
                break;
            case 'trait_names':
                trait_names = values.split(",");
                break;
            case 'weights':
                weights = values.split(",");
                break;
            case 'control_ids':
                control_ids = values.split(",");
                break;
            case 'control_names':
                control_names = values.split(",");
                break;
        }
    }
    jQuery('#selection_index').html("");
    jQuery('#trait_table').html("");
    var omitted_traits = [];
    var omitted_controls = [];

    //add traits, weights, and controls to table
    for (i = 0; i < trait_ids.length; i++) {
        var trait_id = trait_ids[i];
        var control_id = control_ids[i];
        //console.log("building trait table with trait:" + trait_id + trait_names[i] + " and weight:" + weights[i] + " and control:" + control_id + control_names[i]);
        var weight_input_id = trait_id + '_weight';
        var control_select_id = trait_id + '_control';
        var trait_name = jQuery('#trait_list option[value=' + trait_id + ']').text();
        if (!trait_name) {
            omitted_traits.push("<a href='/cvterm/" + trait_id + "/view' data-value='" + trait_id + "'>" + trait_names[i] + "</a>");
            continue;
        }
        var trait_synonym = jQuery('#trait_list option[value=' + trait_id + ']').data("synonym");
        var trait_CO_id = jQuery('#trait_list option[value=' + trait_id + ']').data("co_id");
        var control_html = jQuery('#control_list').html();
        //console.log("control html"+control_html);
        var trait_html = "<tr id='" + trait_id + "_row'><td><a href='/cvterm/" + trait_id + "/view' data-value='" + trait_id + "'>" + trait_name + "</a></td><td><p id='" + trait_id + "_synonym'>" + trait_synonym + "<p></td><td><input type='text' id='" + weight_input_id + "' class='form-control' placeholder='Must be a number (+ or -), default = 1'></input></td><td><select class='form-control' id='" + control_select_id + "'>" + control_html + "</select></td><td align='center'><a title='Remove' id='" + trait_id + "_remove' href='javascript:remove_trait(" + trait_id + ")'><span class='glyphicon glyphicon-remove'></span></a></td></tr>";

        jQuery('#trait_table').append(trait_html);
        jQuery('#' + weight_input_id).val(weights[i]);
        if (jQuery('#' + control_select_id).find('option[value="' + control_id + '"]').length) {
            jQuery('#' + control_select_id).val(control_id);
        } else {
            omitted_controls.push("<a href='/stock/" + control_id + "/view' data-value='" + control_id + "'>" + control_names[i] + "</a>");
        }
    }
    jQuery('#select_message').text('Add another trait');
    jQuery('#select_message').attr('selected', true);
    update_formula();

    if (omitted_traits.length > 0 || omitted_controls.length > 0) {
        document.getElementById('selection_index_error_message').innerHTML = "<center><li class='list-group-item list-group-item-danger'> The following parts of the saved SIN formula have been omitted because they were not found in this trial:</li></center><br><center><p>Traits: " + omitted_traits.join(", ") + "</p></center><br><center><p>Controls: " + omitted_controls.join(", ") + "</p></center>";
        jQuery('#selection_index_error_dialog').modal("show");
    }

}

function remove_trait(trait_id) {
    jQuery('#' + trait_id + '_row').remove();
    update_formula();
}

function update_formula() {
    //console.log("updating formula....");
    var selected_trait_rows = jQuery('#trait_table').children();
    if (selected_trait_rows.length < 1) {
        jQuery('#ranking_formula').html("<center><i>Select a trial, then pick traits and weights (or load a saved formula).</i></center>");
        jQuery('#calculate_rankings').addClass('disabled');
        jQuery('#save_sin').addClass('disabled');
        return;
    }
    var formula = "<center><b>SIN = </b></center>";
    var term_number = 0;
    jQuery(selected_trait_rows).each(function(index, selected_trait_rows) {
        var trait_id = jQuery('a', this).data("value");
        var trait = jQuery('#' + trait_id + '_synonym').text()
        if (trait == 'None') {
          trait = jQuery('a', this).text();
        }
        var trait_term = "mean "+trait;
        var weight = jQuery('#' + trait_id + '_weight').val() || 1; // default = 1
        if (jQuery('#' + trait_id + '_control option:selected').val()) { // if control selected for scaling
            trait_term += " relative to " + jQuery('#' + trait_id + '_control option:selected').text();
        }

        if (term_number == 0 || weight <= 0) {
            formula += "<center>" + weight + " * ( " + trait_term + ")</center>";
        } else {
            formula += "<center>+ " + weight + " * ( " + trait_term + ")</center>";
        }
        term_number++;
    });
    jQuery('#ranking_formula').html(formula);
    jQuery('#calculate_rankings').removeClass('disabled');
    jQuery('#save_sin').removeClass('disabled');
    return;
}
