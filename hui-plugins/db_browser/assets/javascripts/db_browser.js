(function () {
  // function init() {
  //   $(".relation-ajax-menu").popover({
  //     content: $("#popup").html(),
  //     html: true
  //   });

  //   $(document).on('click', ".search_submit_button", function () {
  //     var field_code_name = $(this).closest(".popover").parent().find(".relation-ajax-menu").attr("field_code_name");
  //     var search_word = $(this).closest(".popover").find(".search_text_field").val();
  //     var search_relation_url = "/plugins/_1/db_browser/ajax_search_relation".
  //       replace("_1", window.Hui.db_ajax_data.event_id);
  //     var search_relation_params = {
  //       "_id": window.Hui.db_ajax_data._id,
  //       "class_code_name": window.Hui.db_ajax_data.class_code_name,
  //       "field_code_name": field_code_name,
  //       "search_word": search_word
  //     };
  //     var target_position = $(this).closest(".popover").find(".candidates");
  //     $.get(search_relation_url, search_relation_params, function (data) {
  //       var template = 
  //         ["table", {},
  //          [hiccup.ForEach, data, function (row) {
  //            var _id = row[0];
  //            var row_body = row[1];
  //            return ["tr", {}, 
  //                    ["td", {}, 
  //                     ["a", {"href": "javascript:void(0)",
  //                            "class": "ajax-menu-item",
  //                            "data-id": row[0],
  //                            "field_code_name": field_code_name}, row_body[0]]],
  //                    [hiccup.ForEach, row_body.slice(1), function (d) {
  //                      return ["td", {}, d];
  //                    }]];
  //          }]];
  //       var content = hiccup(template);
  //       target_position.html(content);
  //     });
  //   });

  //   $(document).on('click', ".ajax-menu-item", function () {
  //     var field_code_name = $(this).attr("field_code_name");
  //     var this_text = $(this).html();
  //     var _id = $(this).attr("data-id");
  //     var input_selector = "input[name=_1]".replace("_1", field_code_name);
  //     var ahref_selector = 
  //       "a.relation-ajax-menu[field_code_name=_1]".replace("_1", field_code_name);

  //     var value = JSON.parse($(input_selector).val());
  //     value.push(_id);
  //     $(input_selector).val(JSON.stringify(value));

  //     var text = $(ahref_selector).html();
  //     text += " " + this_text;
  //     $(ahref_selector).html(text);
  //   });
  // }

  var db_data = null;

  var INPUT_ELEMENTS = {
    "string": "<input type='text' name='_field_code_name' value='_current_value'></input>",
    "number": "<input type='number' name='_field_code_name' value='_current_value'></input>",
    "datetime": "<input type='datetime-local' name='_field_code_name' value='_current_value'></input>",
    "boolean": "<select name='_field_code_name'><option value='true'>是</option><option value='false'>否</option></select>"
  };

  function edit_relation_handler(field_code_name) {
    var db_class = find_with_code_name(db_data.schema, db_data.class_code_name);
    var field = find_with_code_name(db_class.fields, field_code_name);

    if(is_relational_type(field["type"])) {
      var template = $(".db-edit-relational").html();
      var instantiated = template.
        replace(/_field_code_name/g, field_code_name).
        replace(/_field_human_name/g, field["human_name"]).
        replace(/['"]_current_value["']/g,
                "'" + JSON.stringify(db_data.row[field_code_name]) + "'");
      // double quote in JSON is specially handled above

      $(".instantiated").find(".modal-content").html(instantiated);
      ajax_load_relation(field_code_name,
                         $(".instantiated").find(".current-value"));
      $(".instantiated").modal("show");        
    } else if(field["type"] === "boolean"){
      var template = $(".db-edit-simple").html();
      var current_value = db_data.row[field_code_name];
      var current_value_human = current_value ? "是" : "否";

      var select = $('<div></div>');
      select.html(INPUT_ELEMENTS["boolean"]);
      var option = select.find("option[value=" + current_value + "]");
      option.attr("selected", "selected");

      var instantiated = template.
        replace(/_input_element/g, select.html()).
        replace(/_field_code_name/g, field_code_name).
        replace(/_field_human_name/g, field["human_name"]).
        replace(/_current_value/g, current_value_human);
      $(".instantiated").find(".modal-content").html(instantiated);
      $(".instantiated").modal("show");
    } else {
      var template = $(".db-edit-simple").html();
      var instantiated = template.
        replace(/_input_element/g, INPUT_ELEMENTS[field["type"]]).
        replace(/_field_code_name/g, field_code_name).
        replace(/_field_human_name/g, field["human_name"]).
        replace(/_current_value/g, db_data.row[field_code_name]);
      $(".instantiated").find(".modal-content").html(instantiated);
      $(".instantiated").modal("show");
    }
  }

  function ajax_load_relation(field_code_name, values_div) {
    var load_relation_params = {
      "_id": db_data._id,
      "field_code_name": field_code_name
    };
    $.get("ajax_load_relation", load_relation_params, function (data) {
      render_relation_list(data, values_div);
      refresh_relation_select_dialog(values_div.closest(".relation-dialog-body"));
    });
  }

  function render_relation_list(values, values_div) {
    var template = 
      ["table", {},
       [hiccup.ForEach, values, function (row) {
         return ["tr", {"class": "rel-row"},
                 ["td", {},
                  ["a", {"href": "javascript:void(0)",
                         "class": "repr",
                         "data-id": row.id},
                   row.cols[0]]],
                 [hiccup.ForEach, row.cols.slice(1), function (d) {
                   return ["td", {}, d];
                 }]];
       }]];
    var content = hiccup(template);
    values_div.html(content);    
  }

  function ajax_search(field_code_name, search_word, values_div) {
    var search_relation_params = {
      "_id": db_data._id,
      "class_code_name": db_data.class_code_name,
      "field_code_name": field_code_name,
      "search_word": search_word
    };

    $.get("ajax_search_relation", search_relation_params, function (data) {
      render_relation_list(data, values_div);
      refresh_relation_select_dialog(values_div.closest(".relation-dialog-body"));
    });
  }

  function refresh_relation_select_dialog(dialog_body) {
    var selected_ids_container = dialog_body.find(".selected-ids");
    var selected_ids = JSON.parse(selected_ids_container.val());
    var current_value = collect_relation_rows(dialog_body.find(".current-value"));
    var candidates = collect_relation_rows(dialog_body.find(".candidates"));
    var all_values =
      stable_unique_by(current_value.concat(candidates), function (row) {
        return row.id;
      });
    var partitions = stable_partition_by_ids(all_values, selected_ids);
    var new_value = partitions.good;
    var new_candidates = partitions.bad;
    render_relation_list(new_value, dialog_body.find(".current-value"));
    render_relation_list(new_candidates, dialog_body.find(".candidates"));
  }

  function collect_relation_rows(container) {
    var row_elements = container.find("tr");
    var result = [];
    for(var i = 0; i < row_elements.length; i++) {
      var row_e = $(row_elements[i]);
      var id = row_e.find(".repr").attr("data-id");
      var texts = [];
      var col_elements = row_e.find("td");
      for(var j = 0; j < col_elements.length; j++) {
        texts.push($(col_elements[j]).text());
      }
      result.push({"id": id, "cols": texts});
    }
    return result;
  }

  function add_selected_relation(row_element) {
    var dialog_body = row_element.closest(".relation-dialog-body");
    var selected_ids_container = dialog_body.find(".selected-ids");
    var selected_ids = JSON.parse(selected_ids_container.val());
    var my_id = row_element.attr("data-id");
    selected_ids.push(my_id);
    selected_ids_container.val(JSON.stringify(selected_ids));
    refresh_relation_select_dialog(dialog_body);
  }

  function remove_selected_relation(row_element) {
    var dialog_body = row_element.closest(".relation-dialog-body");
    var selected_ids_container = dialog_body.find(".selected-ids");
    var selected_ids = JSON.parse(selected_ids_container.val());
    var my_id = row_element.attr("data-id");

    var new_selected_ids = [];
    for(var i = 0; i < selected_ids.length; i++) {
      if(selected_ids[i] !== my_id)
        new_selected_ids.push(selected_ids[i]);
    }

    selected_ids_container.val(JSON.stringify(new_selected_ids));
    refresh_relation_select_dialog(dialog_body);
  }

  function stable_unique_by(arr, f) {
    var to_be_removed = {};
    var f_arr = {};
    var result = [];

    for(var i = 0; i < arr.length; i++) {
      f_arr[i] = f(arr[i]);
    }
    for(var i = 0; i < arr.length; i++) {
      for(var j = 0; j < i; j++) {
        if(f_arr[j] === f_arr[i])
          to_be_removed[i] = "1";
      }
    }
    for(var i = 0; i < arr.length; i++) {
      if(!to_be_removed[i])
        result.push(arr[i]);
    }
    return result;
  }

  function stable_partition_by_ids(full_arr, good_ids) {
    var good = [];
    var bad = [];
    var good_ids_hash = {};
    var full_arr_hash = {};

    for(var i = 0; i < good_ids.length; i++) {
      good_ids_hash[good_ids[i]] = "1";
    }

    for(var i = 0; i < full_arr.length; i++) {
      var item = full_arr[i];
      var id = item.id;
      full_arr_hash[id] = item;
    }

    for(var i = 0; i < full_arr.length; i++) {
      var item = full_arr[i];
      var id = item.id;
      if(!good_ids_hash[id])
        bad.push(item);  // bad is same order as in full_arr
    }

    for(var i = 0; i < good_ids.length; i++) {
      var id = good_ids[i];
      good.push(full_arr_hash[id]); // good is same order as in good_ids
    }

    return {good: good, bad: bad};
  }

  function init() {
    db_data = window.Hui.db_data;

    $(".edit-relation").click(function () {
      var field_code_name = $(this).attr("field-code-name");
      edit_relation_handler(field_code_name);
    });

    $(document).on("click", ".search-submit-button", function () {
      var field_code_name = $(this).attr("field-code-name");
      var search_word = $(this).closest(".relation-dialog-body").
        find(".search-text-field").val();
      var values_div = $(this).closest(".relation-dialog-body").
        find(".candidates");
      ajax_search(field_code_name, search_word, values_div);
    });

    $(document).on("click", ".candidates .repr", function () {
      add_selected_relation($(this));
    });

    $(document).on("click", ".current-value .repr", function () {
      remove_selected_relation($(this));
    });
  }

  // ============= begin: duplicate from db_schema_editor

  function find_with_code_name(coll, code_name) {
    for(var i = 0; i < coll.length; i++) {
      if(coll[i].code_name === code_name)
        return coll[i];
    }
    return null;
  }

  function is_relational_type(type) {
    return (type === "one-to-one" ||
            type === "one-to-many" ||
            type === "many-to-one" ||
            type === "many-to-many");
  }

  // ============= end: duplicate from db_schema_editor

  window.Hui = window.Hui || {};
  window.Hui.db_browser = window.Hui.db_browser || {};
  window.Hui.db_browser.global_show = window.Hui.db_browser.global_show || {};
  window.Hui.db_browser.global_show.onload = init;
})();