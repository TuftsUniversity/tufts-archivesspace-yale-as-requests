$(function() {
  var setup_inline_request_form = function(uri) {
	  
	modal = $("#inline_request_modal"),
        send_btn = modal.find(".action-btn"),
        send_btn.html("Send Request"),
        send_btn.attr("disabled", !0),
        send_btn.unbind("click").click(function () {
            modal.find(".page_action, .request").click(),
            modal.modal("hide")
        }),
        $("#inline-aeon-request-form").html("Retrieving request information ..."),
        modal.modal("show"),
    $('#aeon_request_selector_modal').remove();
    $(document.body).append($('#inline_request_modal_template').html());

    $('#aeon_request_selector_modal .modal-body').empty();
    $('#aeon_request_selector_modal').modal('show');

    loadAeonRequestForm(uri, '');
  };

  window.setup_inline_request_form = setup_inline_request_form;
});




function apply_request_buttons_to_infinite() {
    $(document).on('waypointloaded', '.waypoint', function () {

        $(this).find('.information').addClass('row');
        $(this).find('.information h3').addClass('col-sm-9');

        $(this).find('.infinite-item[data-requestable]').each(function () {
            var section = $(this);
            var requestButton = $('<div class="col-sm-3"></div>');
            var n = $(this).find(".record-type-badge").text();
            var link = $('<a data-toggle="modal" id="aeon-request-button" class="btn btn-default btn-sm" ' +
                         '   style="margin-bottom: 0.5em;"' +
                         '   href="javascript:void(0);">' +
                         '     <i class="fa fa-external-link fa-external-link-alt"></i>' +
                         '     Request ' + n.split(",")[0] + 
                         '</a>');


            link.on('click', function () {
                setup_inline_request_form(section.data('uri'));
            });

            requestButton.append(link);

            section.find('.information').append(requestButton);
        });
    });

}

