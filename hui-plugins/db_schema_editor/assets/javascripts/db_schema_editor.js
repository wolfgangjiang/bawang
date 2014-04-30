var open_form_dialog = (function () {
  function gen_labeled_input(col) {
    return ["div", {},
            ["label", {},
             col.human_name,
             gen_input(col)]];
  }

  function gen_select(name, candidates, selected_value) {
    var select_body = ["select", {"name": name}]
    for(var i = 0; i < candidates.length; i++) {
      var candi = candidates[i];
      if(candi.code_name === selected_value) {
        select_body.push(["option", {"value": candi.code_name,
                                     "selected": "selected"}, candi.human_name]);
      } else {
        select_body.push(["option", {"value": candi.code_name}, candi.human_name]);
      }
    }
    return select_body;
  }

  function gen_input(col) {
    switch(col.type) {
    case "string": 
      return ["input", {"type": "text",
                        "name": col.code_name,
                        "value": col.old_value}];
    case "number":
      return ["input", {"type": "number",
                        "name": col.code_name,
                        "value": col.old_value}];
    case "date":
    case "datetime":
      return ["input", {"type": "date",
                        "name": col.code_name,
                        "value": col.old_value}];
    case "boolean":
      var boolean_candidates = [{"code_name": "true", "human_name": "是"},
                                {"code_name": "false", "human_name": "否"}];
      var stringified_old_value = col.old_value ? "true" : "false";
      return gen_select(col.code_name, boolean_candidates, stringified_old_value);
    case "enum":
      return gen_select(col.code_name, col.candidates, col.old_value);
    default:
      throw "open_form_dialog: unknown input type: " + col.type;
    }
  }

  function gen_ok_button() {
    return ["button", {"class": "dialog_button ok"}, "确定"];
  }

  function gen_cancel_button() {
    return ["button", {"class": "dialog_button cancel"}, "取消"];
  }

  function gen_error_message_field() {
    return ["div", {"class": "error_message"}, ""];
  }

  function render_dialog(dialog_body) {
    var overlay = ["div", {"class": "modal_overlay"},
                   dialog_body];
    $("body").append(hiccup(overlay));
  }

  function close_dialog() {
    $(".modal_overlay").remove();
  }

  function humanize(message, params) {
    var m = message;
    for(var i = 0; i < params.columns.length; i++) {
      var col = params.columns[i];
      var regexp = new RegExp(col.code_name, "g");
      m = m.replace(regexp, col.human_name);
    }
    return m;
  }

  function bind_listeners(params, validate, ret) {
    $(".dialog .ok").click(function () {
      var data = collect_data(params);

      if(validate) {
        var validity = validate(data);
        if(validity.err) {
          var message = humanize(validity.message, params);
          $(".dialog .error_message").html(message);
          return;
        } 
      }

      setTimeout(function () {
        close_dialog();
        ret(data);
      }, 0);
    });

    $(".dialog .cancel").click(function () {
      setTimeout(function () {
        close_dialog();
      }, 0);
    });
  }

  function collect_data(params) {
    var data = {"row_code_name": params.row_code_name,
                "columns": []};

    for(var i = 0; i < params.columns.length; i++) {
      var col = params.columns[i];

      var value = collect_input(col);
      data.columns[col.code_name] = value;
    }

    return data;
  }

  function collect_input(col) {
    var css_selector = "";
    switch(col.type) {
    case "string":
    case "number":
    case "date":
    case "datetime":
      css_selector = ".dialog input[name=_1]".replace("_1", col.code_name);
      return $(css_selector).val();
    case "boolean":
      css_selector = ".dialog select[name=_1]".replace("_1", col.code_name);
      var value = $(css_selector).val();
      if(value === "true") {
        return true;
      } else if(value === "false") {
        return false;
      } else {
        return null;
      }
    case "enum":
      css_selector = ".dialog select[name=_1]".replace("_1", col.code_name);
      return $(css_selector).val();
    default:
      return null;
    }
  }

  function open_dialog(metrics, params, validate, ret) {
    var dialog_body = ["div", {"class":"dialog"}];
    for(var i = 0; i < params.columns.length; i++) {
      var col = params.columns[i];
      var input = gen_labeled_input(col);
      if(input)
        dialog_body.push(input);
      // unknown col.type is silently ignored
    }

    dialog_body.push(gen_error_message_field());
    dialog_body.push(gen_ok_button());
    dialog_body.push(gen_cancel_button());

    render_dialog(dialog_body);

    bind_listeners(params, validate, ret);
  }

  return open_dialog;
})();


(function () {
  var the_schema = null;
  var old_schema = null;

  var FIELD_TYPE_CANDIDATES =
    [{"code_name": "string", "human_name": "字符串"},
     {"code_name": "number", "human_name": "数值"},
     {"code_name": "datetime", "human_name": "日期时间"},
     {"code_name": "boolean", "human_name": "是非"},
     {"code_name": "one-to-one", "human_name" : "一对一"},
     {"code_name": "one-to-many", "human_name" : "一对多"},
     {"code_name": "many-to-one", "human_name" : "多对一"},
     {"code_name": "many-to-many", "human_name" : "多对多"}];
  
  function TheSchemaPanel(the_schema) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
      self.new_class_link.bind();
      self.save_button.bind();
      self.class_list.bind();
    };

    var validity = new GlobalValidator(the_schema).validate();
    var dirty = !deep_equals(the_schema, old_schema);

    self.new_class_link = new NewClassLink();
    self.save_button = new SaveButton(dirty, validity);
    self.class_list = new ClassList(the_schema);

    self.render = function () {
      return ["div", {"id": self.id, "class": "the_schema_panel"},
              self.new_class_link.render(),
              self.save_button.render(),
              self.class_list.render()];
    }; 
    
    self.onclick = function () {};
  }

  function NewClassLink() {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };

    self.render = function () {
      return ["a", {"id": self.id, 
                    "class": "new_class_link",
                    "href": "javascript:void(0)"}, "新建类"];
    };

    self.onclick = function () {    
      var dialog_params =
        {"columns":
         [{"code_name": "code_name", "human_name": "代码名", "type": "string"},
          {"code_name": "human_name", "human_name": "显示用名", "type": "string"}]};
      open_form_dialog(null, dialog_params, validate, function (data) {
        var added_class = {"code_name": data.columns.code_name,
                           "human_name": data.columns.human_name,
                           "fields": []};
        the_schema.push(added_class);
        render_all();
      });
    };

    function validate(data) {
      var validate_ensure_non_empty =
        create_validations_for_ensuring_non_empty("code_name", "human_name");

      function validate_ensure_unique(data) {
        var target = data.columns.code_name;

        for(var i = 0; i < the_schema.length; i++) {
          var cl = the_schema[i];
          if(cl.code_name === target) {
            return {
              "err": true,
              "message": "code_name " + target + " 重复存在了"
            }
          }
        }
        return {"ok": true};
      }

      var combined_validate = combine_validations(
        validate_ensure_non_empty,
        validate_ensure_unique);

      return combined_validate(data);
    }
  }

  function SaveButton(dirty, validity) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.dirty = dirty;

    self.render = function () {
      var validity_info = ["span", {}, "正常"];
      if(validity.err)
        validity_info = ["div", {}, validity.message];

      if(self.dirty && validity.ok) {
        return ["span", {},
                "已经修改过，无错误", 
                ["button", {"id": self.id, "class": "save_button"}, "保存"]];
      } else if(self.dirty && validity.err) {
        return ["span", {},
                "已经修改过，有错误，不允许保存",
                ["div", {"class": "global_validity_fail"}, validity.message]];
      } else if(!self.dirty && validity.ok) {
        return ["span", {}, "尚未修改，无错误"];
      } else {
        return ["span", {},
                "尚未修改，有错误，不允许保存",
                ["div", {"class": "global_validity_fail"}, validity.message]];
      }
    };

    self.onclick = function () {
      $("#data_to_be_saved").val(JSON.stringify(the_schema));
      $(".save_form").submit();      
    }
  }

  function ClassList(classes_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
      for(var i = 0; i < self.classes.length; i++) {
        self.classes[i].bind();
      }
    }

    self.classes = [];
    for(var i = 0; i < classes_data.length; i++) {
      self.classes.push(new DbClass(classes_data[i]));
    }

    self.render = function () {
      return ["div", {"id": self.id, "class": "class_list"},
              [hiccup.ForEach, self.classes, function (cl) {
                return cl.render();
              }]];
    };

    self.onclick = function () {};
  }

  function DbClass(class_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
      self.code_name.bind();
      self.human_name.bind();
      self.move_up_link.bind();
      self.move_down_link.bind();
      self.remove_link.bind();
      self.new_field_link.bind();
      self.field_list.bind();
    };

    self.code_name = new ClassCodeName(class_data);
    self.human_name = new ClassHumanName(class_data);
    self.move_up_link = new ClassMoveUpLink(class_data);
    self.move_down_link = new ClassMoveDownLink(class_data);
    self.remove_link = new RemoveClassLink(class_data);
    self.new_field_link = new NewFieldLink(class_data);
    self.field_list = new FieldList(class_data.fields);

    self.render = function () {
      return ["div", {"id": self.id, "class": "db_class"},
              self.code_name.render(),
              self.human_name.render(),
              self.move_up_link.render(),
              self.move_down_link.render(),
              self.remove_link.render(),
              self.new_field_link.render(),
              self.field_list.render()];
    };
    
    self.onclick = function () {};
  }

  function ClassCodeName(class_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.class_data = class_data;

    self.render = function () {
      return ["span", {"id": self.id, "class": "class_code_name"},
              self.class_data.code_name]
    };

    self.onclick = function () {};
  }

  function ClassHumanName(class_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.class_data = class_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "class_human_name",
                    "href": "javascript:void(0)"}, self.class_data.human_name];
    };

    self.onclick = function () {
      var dialog_params = 
        {"row_code_name": self.class_data.code_name,
         "columns": [{"code_name": "human_name",
                      "human_name": "显示用名",
                      "type": "string",
                      "old_value": self.class_data.human_name}]};
      open_form_dialog(null, dialog_params, validate, function (data) {
        var db_class = find_with_code_name(the_schema, self.class_data.code_name);
        db_class.human_name = data.columns.human_name;

        render_all();
      });      
    };

    function validate(data) {
      var validate_ensure_non_empty =
        create_validations_for_ensuring_non_empty("human_name");
      return validate_ensure_non_empty(data);
    }
  }

  function RemoveClassLink(class_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.class_data = class_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "remove_class_link",
                    "href": "javascript:void(0)"}, "删除"];
    };

    self.onclick = function () {
      the_schema = remove_with_code_name(the_schema, self.class_data.code_name);

      render_all();
    };
  }

  function ClassMoveUpLink(class_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.class_data = class_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "class_move_up_link",
                    "href": "javascript:void(0)"}, "上移"];
    };

    self.onclick = function () {
      the_schema = move_up_with_code_name(the_schema, self.class_data.code_name);

      render_all();
    };
  }

  function ClassMoveDownLink(class_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.class_data = class_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "class_move_down_link",
                    "href": "javascript:void(0)"}, "下移"];
    };

    self.onclick = function () {
      the_schema = move_down_with_code_name(the_schema, self.class_data.code_name);

      render_all();
    };
  }

  function NewFieldLink(class_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.class_data = class_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "new_field_link",
                    "href": "javascript:void(0)"}, "新建字段"];
    }

    self.onclick = function () {
      var dialog_params = 
        {"row_code_name": self.class_data.code_name,
         "columns": [{"code_name": "code_name",
                      "human_name": "代码名",
                      "type": "string"},
                     {"code_name": "human_name",
                      "human_name": "显示用名",
                      "type": "string"},
                     {"code_name": "type",
                      "human_name": "类型",
                      "type": "enum",
                      "candidates": FIELD_TYPE_CANDIDATES}]};

      open_form_dialog(null, dialog_params, validate, function (data) {
        var added_field = {"class_code_name": self.class_data.code_name,
                           "code_name": data.columns.code_name,
                           "human_name": data.columns.human_name,
                           "type": data.columns.type};
        var db_class = find_with_code_name(the_schema, self.class_data.code_name);
        db_class.fields = db_class.fields || [];
        db_class.fields.push(added_field);

        render_all();
      });
    };

    function validate(data) {
      var validate_ensure_non_empty =
        create_validations_for_ensuring_non_empty("code_name", "human_name");

      function validate_ensure_unique(data) {
        var target = data.columns.code_name;
        var db_class = find_with_code_name(the_schema, self.class_data.code_name);

        for(var i = 0; i < db_class.fields.length; i++) {
          var f = db_class.fields[i];
          if(f.code_name === target) {
            return {
              "err": true,
              "message": "code_name " + target + " 在类内重复存在了"
            }
          }
        }
        return {"ok": true};
      }

      var combined_validate = combine_validations(
        validate_ensure_non_empty,
        validate_ensure_unique);

      return combined_validate(data);
    }
  }

  function FieldList(fields_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
      for(var i = 0; i < self.fields.length; i++) {
        self.fields[i].bind();
      }
    };

    function field_factory_create(field_data) {
      switch(field_data.type) {
      case "string":
        return new StringField(field_data);
      case "one-to-one":
      case "one-to-many":
      case "many-to-one":
      case "many-to-many":
        return new RelationalField(field_data);
      default:
        return new BasicField(field_data);
      }
    }

    self.fields = [];
    fields_data = fields_data || [];
    for(var i = 0; i < fields_data.length; i++) {
      self.fields.push(field_factory_create(fields_data[i]));
    }

    self.render = function () {
      return ["div", {"id": self.id, "class": "field_list"},
              [hiccup.ForEach, self.fields, function (f) {
                return f.render();
              }]];
    };

    self.onclick = function () {};
  }

  function BasicField(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
      self.code_name.bind();
      self.human_name.bind();
      self.type.bind();
      self.move_up_link.bind();
      self.move_down_link.bind();
      self.remove_link.bind();
    };

    self.code_name = new FieldCodeName(field_data);
    self.human_name = new FieldHumanName(field_data);
    self.type = new FieldType(field_data);
    self.move_up_link = new FieldMoveUpLink(field_data);
    self.move_down_link = new FieldMoveDownLink(field_data);
    self.remove_link = new RemoveFieldLink(field_data);

    self.render = function () {
      return  ["div", {"id": self.id, "class": "field"},
               self.code_name.render(),
               self.human_name.render(),
               self.type.render(),
               self.move_up_link.render(),
               self.move_down_link.render(),
               self.remove_link.render()];
    };
    
    self.onclick = function () {};
  }

  function StringField(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
      self.code_name.bind();
      self.human_name.bind();
      self.type.bind();
      self.is_repr.bind();
      self.move_up_link.bind();
      self.move_down_link.bind();
      self.remove_link.bind();
    };

    self.code_name = new FieldCodeName(field_data);
    self.human_name = new FieldHumanName(field_data);
    self.type = new FieldType(field_data);
    self.is_repr = new FieldIsRepr(field_data);
    self.move_up_link = new FieldMoveUpLink(field_data);
    self.move_down_link = new FieldMoveDownLink(field_data);
    self.remove_link = new RemoveFieldLink(field_data);

    self.render = function () {
      return  ["div", {"id": self.id, "class": "field"},
               self.code_name.render(),
               self.human_name.render(),
               self.type.render(),
               self.is_repr.render(),
               self.move_up_link.render(),
               self.move_down_link.render(),
               self.remove_link.render()]
    };
    
    self.onclick = function () {};
  }

  function RelationalField(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
      self.code_name.bind();
      self.human_name.bind();
      self.type.bind();
      self.reverse_class.bind();
      self.reverse_field.bind();
      self.move_up_link.bind();
      self.move_down_link.bind();
      self.remove_link.bind();
    };

    self.code_name = new FieldCodeName(field_data);
    self.human_name = new FieldHumanName(field_data);
    self.type = new FieldType(field_data);
    self.reverse_class = new FieldReverseClass(field_data);
    self.reverse_field = new FieldReverseField(field_data);
    self.move_up_link = new FieldMoveUpLink(field_data);
    self.move_down_link = new FieldMoveDownLink(field_data);
    self.remove_link = new RemoveFieldLink(field_data);

    self.render = function () {
      return  ["div", {"id": self.id, "class": "field"},
               self.code_name.render(),
               self.human_name.render(),
               self.type.render(),
               self.reverse_class.render(),
               self.reverse_field.render(),
               self.move_up_link.render(),
               self.move_down_link.render(),
               self.remove_link.render()]
    };
    
    self.onclick = function () {};
  }

  function FieldCodeName(field_data) { 
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      return ["span", {"id": self.id, "class": "field_code_name"},
              self.field_data.code_name]
    };

    self.onclick = function () {};
  }

  function FieldHumanName(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "field_human_name",
                    "href": "javascript:void(0)"}, self.field_data.human_name];
    };

    self.onclick = function () {
      var dialog_params =
        {"row_code_name": self.field_data.code_name,
         "columns": [{"code_name": "human_name",
                      "human_name": "显示用名",
                      "type": "string",
                      "old_value": self.field_data.human_name}]};
      open_form_dialog(null, dialog_params, validate, function (data) {
        var db_class =
          find_with_code_name(the_schema, self.field_data.class_code_name);
        var field = 
          find_with_code_name(db_class.fields, self.field_data.code_name);
        field.human_name = data.columns.human_name;

        render_all();
      });      
    };

    function validate(data) {
      var validate_ensure_non_empty =
        create_validations_for_ensuring_non_empty("human_name");
      return validate_ensure_non_empty(data);
    }
  }

  function FieldType(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      var type_repr =
        (find_with_code_name(FIELD_TYPE_CANDIDATES, self.field_data.type) ||
         {"human_name": self.field_data.type})

      return ["a", {"id": self.id, "class": "field_type",
                    "href": "javascript:void(0)"}, type_repr.human_name];
    };

    self.onclick = function () {
      var dialog_params = 
        {"row_code_name": self.field_data.class_code_name,
         "columns": [{"code_name": "type",
                      "human_name": "类型",
                      "type": "enum",
                      "old_value": self.field_data.type,
                      "candidates": FIELD_TYPE_CANDIDATES}]};

      open_form_dialog(null, dialog_params, null, function (data) {
        var db_class =
          find_with_code_name(the_schema, self.field_data.class_code_name);
        var field = 
          find_with_code_name(db_class.fields, self.field_data.code_name);
        field.type = data.columns.type;
        var reverse_type = get_reverse_relation(field.type);
        if(reverse_type) {
          spread_modification_to_reverse_field(
            self.field_data.reverse_class,
            self.field_data.reverse_field,
            reverse_type);
        }

        render_all();
      });
    };

    function spread_modification_to_reverse_field(reverse_class_code_name, reverse_field_code_name, reverse_type) {
      var r_class =
        find_with_code_name(the_schema, reverse_class_code_name);
      if(r_class) {
        var r_field = 
          find_with_code_name(r_class.fields, reverse_field_code_name);
        if(r_field) {
          r_field.type = reverse_type;
        }
      }
    }
  }

  function FieldIsRepr(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      var repr = self.field_data.is_repr ? "代表" : "_";

      return ["a", {"id": self.id, "class": "field_is_repr",
                    "href": "javascript:void(0)"}, repr];
    };

    self.onclick = function () {
      var dialog_params = 
        {"row_code_name": self.field_data.class_code_name,
         "columns": [{"code_name": "is_repr",
                      "human_name": "是否代表",
                      "type": "boolean",
                      "old_value": !!self.field_data.is_repr}]};
      open_form_dialog(null, dialog_params, null, function (data) { 
        var db_class =
          find_with_code_name(the_schema, self.field_data.class_code_name);
        var field = 
          find_with_code_name(db_class.fields, self.field_data.code_name);
        field.is_repr = !!data.columns.is_repr;

        render_all();
      });
    };
  }

  function FieldReverseClass(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      var reverse_human_name = "（未指定）";
      var reverse_class =
        find_with_code_name(the_schema, self.field_data.reverse_class);

      if(reverse_class)
        reverse_human_name = reverse_class.human_name;

      return ["span", {"class": "field_reverse_class_label"},
              "对应：",
              ["a", {"id": self.id, "class": "field_reverse_class",
                     "href": "javascript:void(0)"}, reverse_human_name]];
    };

    self.onclick = function () {
      var possible_reverse_classes =
        remove_with_code_name(the_schema, self.field_data.class_code_name);

      var dialog_params =
        {"row_code_name": self.field_data.code_name,
         "columns": [{"code_name": "reverse_class",
                      "human_name": "对应类",
                      "type": "enum",
                      "old_value": self.field_data.reverse_class,
                      "candidates": possible_reverse_classes}]};
      open_form_dialog(null, dialog_params, null, function (data) {
        var db_class =
          find_with_code_name(the_schema, self.field_data.class_code_name);
        var field = 
          find_with_code_name(db_class.fields, self.field_data.code_name);
        field.reverse_class = data.columns.reverse_class;
        field.reverse_field = null;

        render_all();
      });
    };
  }

  function FieldReverseField(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      var reverse_human_name = "（未指定）";
      var reverse_class =
        find_with_code_name(the_schema, self.field_data.reverse_class);

      if(reverse_class) {
        var reverse_field =
          find_with_code_name(reverse_class.fields, self.field_data.reverse_field);
        if(reverse_field)
          reverse_human_name = reverse_field.human_name;
      }

      return ["span", {"class": "field_reverse_field_label"},
              "的",
              ["a", {"id": self.id, "class": "field_reverse_field",
                     "href": "javascript:void(0)"}, reverse_human_name]];
    };

    self.onclick = function () {
      var candidates = get_possible_reverse_fields();

      var dialog_params =
        {"row_code_name": self.field_data.code_name,
         "columns": [{"code_name": "reverse_field",
                      "human_name": "对应字段",
                      "type": "enum",
                      "old_value": self.field_data.reverse_field,
                      "candidates": candidates}]};
      open_form_dialog(null, dialog_params, null, function (data) {
        var db_class =
          find_with_code_name(the_schema, self.field_data.class_code_name);
        var field = 
          find_with_code_name(db_class.fields, self.field_data.code_name);
        field.reverse_field = data.columns.reverse_field;
        spread_modification_to_reverse_field(
          self.field_data.reverse_class, field.reverse_field);

        render_all();
      });
    };

    function get_possible_reverse_fields() {
      var default_candidates = [{"code_name": "", "human_name": "（未指定）"}];
      var possible_reverse_fields = [];
      var reverse_class =
        find_with_code_name(the_schema, self.field_data.reverse_class);

      if(reverse_class) {
        for(var i = 0; i < reverse_class.fields.length; i++) {
          if(is_relational_type(reverse_class.fields[i].type)) {
            possible_reverse_fields.push(reverse_class.fields[i]);
          }
        }
      }
      if(possible_reverse_fields.length > 0)
        return possible_reverse_fields;
      else
        return default_candidates;
    }

    function spread_modification_to_reverse_field(reverse_class_code_name, reverse_field_code_name) {
      var r_class =
        find_with_code_name(the_schema, reverse_class_code_name);
      if(r_class) {
        var r_field = 
          find_with_code_name(r_class.fields, reverse_field_code_name);
        if(r_field) {
          r_field.reverse_class = self.field_data.class_code_name;
          r_field.reverse_field = self.field_data.code_name;
          r_field.type = get_reverse_relation(self.field_data.type);
        }
      }
    }
  }

  function RemoveFieldLink(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "remove_field_link",
                    "href": "javascript:void(0)"}, "删除"];
    };

    self.onclick = function () {
      var db_class =
        find_with_code_name(the_schema, self.field_data.class_code_name);
      db_class.fields =
        remove_with_code_name(db_class.fields, self.field_data.code_name);

      render_all();
    };
  }

  function FieldMoveUpLink(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "field_move_up_link",
                    "href": "javascript:void(0)"}, "上移"];
    };

    self.onclick = function () {
      var db_class =
        find_with_code_name(the_schema, self.field_data.class_code_name);
      db_class.fields =
        move_up_with_code_name(db_class.fields, self.field_data.code_name);

      render_all();
    };
  }

  function FieldMoveDownLink(field_data) {
    var self = this;
    self.id = get_unique_id();
    self.bind = function () {
      $("#" + self.id).click(self.onclick);
    };
    self.field_data = field_data;

    self.render = function () {
      return ["a", {"id": self.id, "class": "field_move_down_link",
                    "href": "javascript:void(0)"}, "下移"];
    };

    self.onclick = function () {
      var db_class =
        find_with_code_name(the_schema, self.field_data.class_code_name);
      db_class.fields =
        move_down_with_code_name(db_class.fields, self.field_data.code_name);

      render_all();
    };
  }

  function GlobalValidator(schema) {
    var self = this;

    function validate_class_names_non_empty(schema) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < schema.length; i++) {
          var cl = schema[i];
          if(!cl.code_name)
            error_messages.push("类的代码名为空");
          if(!cl.human_name)
            error_messages.push("类 " + cl.code_name + " 的显示用名为空");
        }
      });
    }

    function validate_field_names_non_empty(schema) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < schema.length; i++) {
          var cl = schema[i];
          for(var j = 0; j < cl.fields.length; j++) {
            var f = cl.fields[j];
            if(!f.code_name)
              error_messages.push("类 " + cl.code_name + " 有字段的代码名为空");
            if(!f.human_name)
              error_messages.push("类 " + cl.code_name + " 的字段 " +
                                  f.code_name +" 的显示用名为空");
          }
        }
      });
    }

    function validate_class_names_unique(schema) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < schema.length; i++) {
          var cl = schema[i];
          var code_name_count = count_if(schema, function (other_cl) {
            return other_cl.code_name === cl.code_name;
          });
          if(code_name_count > 1)
            error_messages.push("类 " + cl.code_name + " 的代码名重复了");
          var human_name_count = count_if(schema, function (other_cl) {
            return other_cl.human_name === cl.human_name;
          });
          if(human_name_count > 1)
            error_messages.push("类 " + cl.code_name + " 的显示用名重复了");
        }
      });
    }

    function validate_field_names_unique(schema) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < schema.length; i++) {
          var cl = schema[i];
          for(var j = 0; j < cl.fields.length; j++) {
            var f = cl.fields[j];
            var code_name_count = count_if(cl.fields, function (other_f) {
              return other_f.code_name === f.code_name;
            });
            if(code_name_count > 1)
              error_messages.push("类 " + cl.code_name + " 中字段 " +
                                  f.code_name + " 的代码名重复了");
            var human_name_count = count_if(cl.fields, function (other_f) {
              return other_f.human_name === f.human_name;
            });
            if(human_name_count > 1)
              error_messages.push("类 " + cl.code_name + " 中字段 " +
                                  f.code_name + " 的显示用名重复了");
          }
        }
      });
    }

    function validate_exactly_one_repr_field(schema) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < schema.length; i++) {
          var cl = schema[i];
          var repr_count = count_if(cl.fields, function (f) {
            return (f.type === "string" && f.is_repr);
          });
          if(repr_count === 0)
            error_messages.push("类 " + cl.code_name + " 没有代表字段");
          else if(repr_count > 1)
            error_messages.push("类 " + cl.code_name + " 的代表字段多于一个");
        }
      });
    }

    function validate_unspecified_relations(schema) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < schema.length; i++) {
          var cl = schema[i];
          for(var j = 0; j < cl.fields.length; j++) {
            var f = cl.fields[j];

            if(is_relational_type(f.type)) {
              if(!f.reverse_class)
                error_messages.push("类 " + cl.code_name + " 中字段 " +
                                    f.code_name + " 的关系类未指定");
              if(!f.reverse_field)
                error_messages.push("类 " + cl.code_name + " 中字段 " +
                                    f.code_name + " 的关系字段未指定");
            }
          }
        }
      });
    }

    function validate_assymetrical_relations(schema) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < schema.length; i++) {
          var cl = schema[i];
          for(var j = 0; j < cl.fields.length; j++) {
            var f = cl.fields[j];

            if(is_relational_type(f.type) && f.reverse_class && f.reverse_field) {
              var r_class =
                find_with_code_name(the_schema, f.reverse_class);
              if(r_class) {
                var r_field = 
                  find_with_code_name(r_class.fields, f.reverse_field);
                if(r_field) {
                  if(r_field.reverse_class != cl.code_name ||
                     r_field.reverse_field != f.code_name ||
                     r_field.type != get_reverse_relation(f.type)) {
                    error_messages.push("类 " + cl.code_name + " 中字段 " +
                                        f.code_name + " 对应的关系是不对称的");
                  }
                } else {
                  error_messages.push("类 " + cl.code_name + " 中字段 " +
                                      f.code_name + " 对应的关系字段不存在");
                }
              } else {
                error_messages.push("类 " + cl.code_name + " 中字段 " +
                                    f.code_name + " 对应的关系类不存在");
              }
            }
          }
        }
      });
    }

    self.validate = function () {
      var combined_validate = 
        combine_validations(validate_class_names_non_empty,
                            validate_field_names_non_empty,
                            validate_class_names_unique,
                            validate_field_names_unique,
                            validate_exactly_one_repr_field,
                            validate_unspecified_relations,
                            validate_assymetrical_relations);

      return combined_validate(schema);
    }
  }

  function find_with_code_name(coll, code_name) {
    for(var i = 0; i < coll.length; i++) {
      if(coll[i].code_name === code_name)
        return coll[i];
    }
    return null;
  }

  function remove_with_code_name(coll, code_name) {
    var result = [];
    for(var i = 0; i < coll.length; i++) {
      if(coll[i].code_name !== code_name)
        result.push(coll[i]);
    }
    return result;
  }

  function count_if(arr, fn) {
    var count = 0;
    for(var i = 0; i < arr.length; i++) {
      if(fn(arr[i]))
        count++;
    }
    return count;
  }

  function unique(arr) {
    return $.grep(arr, function (e, i) {
      return i === $.inArray(e, arr);
    });
  }

  function get_index_with_code_name(coll, code_name) {
    for(var i = 0; i < coll.length; i++) {
      if(coll[i].code_name === code_name)
        return i;
    }
    return -1;
  }

  function is_on_top_with_code_name(coll, code_name) {
    return get_index(coll, code_name) === 0;
  }

  function is_on_bottom_with_code_name(coll, code_name) {
    return get_index(coll, code_name) === coll.length;
  }

  function insert_at(coll, ele, index) {
    var result = [];

    for(var i = 0; i < coll.length; i++) {
      if(index === i)
        result.push(ele);
      result.push(coll[i]);
    }

    if(index >= coll.length)
      result.push(ele);

    return result;
  }

  function move_up_with_code_name(coll, code_name) {
    var index = get_index_with_code_name(coll, code_name);
    if(index > 0) {
      var row = find_with_code_name(coll, code_name);
      var deleted = remove_with_code_name(coll, code_name);
      var inserted = insert_at(deleted, row, index - 1);
      return inserted;
    } else {
      return coll;
    }
  }

  function move_down_with_code_name(coll, code_name) {
    var index = get_index_with_code_name(coll, code_name);
    if(index < coll.length - 1) {
      var row = find_with_code_name(coll, code_name);
      var deleted = remove_with_code_name(coll, code_name);
      var inserted = insert_at(deleted, row, index + 1);
      return inserted;
    } else {
      return coll;
    }
  }
 
  function get_unique_id () {
    var possible = "1234567890abcdef";
    var result = [];
    for(var i = 0; i < 40; i++)
      result.push(possible.charAt(Math.floor(Math.random() * possible.length)));

    return result.join("");
  }

  function get_reverse_relation(rel) {
    var MAP = {
      "one-to-one": "one-to-one",
      "one-to-many": "many-to-one",
      "many-to-one": "one-to-many",
      "many-to-many": "many-to-many"
    }

    return MAP[rel];
  }

  function is_relational_type(type) {
    return (type === "one-to-one" ||
            type === "one-to-many" ||
            type === "many-to-one" ||
            type === "many-to-many");
  }

  function with_error_messages(fn) {
    var error_messages = [];

    fn(error_messages);
    
    if(error_messages.length === 0)
      return {"ok": true};
    else
      return {"err": true,
              "message": unique(error_messages).join(",")};
  }

  function create_validations_for_ensuring_non_empty() {
    var keys = arguments;
    return function (data) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < keys.length; i++) {
          var k = keys[i];
          if(!data.columns[k])
            error_messages.push(k + "不能为空");
        }
      });
    };
  }

  function combine_validations() {
    var validations = arguments;
    return function (data) {
      return with_error_messages(function (error_messages) {
        for(var i = 0; i < validations.length; i++) {
          var validate = validations[i];
          var validity = validate(data);
          if(validity.err) {
            error_messages.push(validity.message);
          }
        }
      });
    };
  }

  function deep_equals(a, b) {
    function is_array(x) {
      return Object.prototype.toString.call(x) === "[object Array]";
    }

    function is_object(x) {
      return (typeof x) === "object";
    }

    if(is_array(a) && is_array(b)) {
      if(a.length === b.length) {
        for(var i = 0; i < a.length; i++) {
          if(!deep_equals(a[i], b[i])) {
            return false;
          }
        }
        return true;
      } else {
        return false;
      }
    } else if(is_object(a) && is_object(b)) {
      for(var k in a) {
        if(!deep_equals(a[k], b[k])) {
          return false;
        }
      }
      for(var k in b) {
        if(!deep_equals(a[k], b[k])) {
          return false;
        }
      }
      return true;
    } else {
      return a === b;
    }
  }

  function render_all() {
    var the_schema_panel = new TheSchemaPanel(the_schema);

    $("#the_schema_container").html(hiccup(the_schema_panel.render()));

    the_schema_panel.bind();
  }

  function init() {
    the_schema = window.the_schema;
    old_schema = JSON.parse(JSON.stringify(the_schema));

    if(!the_schema)
      the_schema = [];

    render_all();
  }

  window.Hui = window.Hui || {};
  window.Hui.db_schema_editor = window.Hui.db_schema_editor || {};
  window.Hui.db_schema_editor.edit = window.Hui.db_schema_editor.edit || {};
  window.Hui.db_schema_editor.edit.onload = init;
})();