// ================= 以下是页面模板工具 hiccup ===================

function hiccup(hic) {
  var hiclen;

  function encodeHTML(raw) {
    return raw.
      replace('&', '&amp;').
      replace('<', '&lt;').
      replace('>', '&gt;').
      replace('"', '&quot;').
      replace("'", '&#39;');
  }

  function foreach() {
    var list = hic[1];
    var func = hic[2];
    var self = "";
    var list_len = list.length;
    for(var i = 0; i < list_len; i++) 
      self += hiccup(func(list[i], i));
    return self;
  }

  function normal() {
    var open_tag = "<" + hic[0];
    var close_tag = "</" + hic[0] + ">";

    if(hiclen == 1)
      return open_tag + " />";

    var attributes = hic[1];

    for(var key in attributes)
      open_tag += " " + key + "=\"" + (attributes[key] || "").replace(/\"/g, "\\\"") + "\"";

    // if(hiclen == 2)
    //     return open_tag + " />";

    open_tag += ">";

    var self = open_tag;

    // loop from hic[2], if any.
    // members from hic[2] on are chidren elements.
    // if hiclen == 2, then loop will not be performed at all.
    for(var i = 2; i < hiclen; i++)
      self += hiccup(hic[i]);

    return self + close_tag;
  }

  if(Object.prototype.toString.call(hic) !== '[object Array]')
    return encodeHTML(hic.toString()); // atomic element    

  hiclen = hic.length;

  if(hiclen == 0)
    return "";

  if(hic[0] === hiccup.ForEach)
    return foreach();

  return normal();
}

hiccup.ForEach = new Object();

// module.exports = hiccup;

// 以上是页面模板工具 hiccup

