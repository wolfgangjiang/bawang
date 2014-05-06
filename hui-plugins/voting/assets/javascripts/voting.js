(function () {
  function poll() {
    $.get("poll_question_status", {"id": window.Hui.q_id}, function (data) {
      $(".remaining-time").html(data.remaining_time_message);
      for(var i = 0; i < data.options.length; i++) {
        var o = data.options[i];
        $(".option-count-" + o["option_tag"]).html(o["count"]);
      }
      setTimeout(poll, 3000);
    });
  }


  window.Hui = window.Hui || {};
  window.Hui.voting = window.Hui.voting || {};
  window.Hui.voting.question = window.Hui.voting.question || {};
  window.Hui.voting.question.onload = function () {
    poll();
  };
})();
