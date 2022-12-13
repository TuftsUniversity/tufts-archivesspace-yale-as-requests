(function(exp) {

    exp.isFindAidView = function() {
        return $('#collection-feed.infinite-record-container').length === 1;
    };
    var requestType = 'reading_room';
 

    exp.loadAeonRequestForm = function(recordURI, requestType) {
        alert("Self URI from function: " + recordURI);
        if (recordURI.includes(" - ")) {
           var parameters = recordURI.split(' - ')
           var uri = parameters[0]
           var finding_aid_view = parameters[1]
        
           alert("Parsed URI: " + uri);
           alert("Parsed Finding Aid View: " + finding_aid_view);        
           $.ajax({
              url: APP_PATH + 'aeon/aeon-request-popup',
              method: 'post',
              data: {
                 uri: uri,
                 request_type: requestType,
                 finding_aid_view: finding_aid_view,
              },
              success: function (html) {
                 $('#aeon_request_selector_modal .modal-body').html(html);
                 new AeonRequestForm(recordURI, $('#aeon_request_selector_modal .modal-body form'));
              },
              error: function (jqXHR, textStatus, errorThrown) {
            
             
                  $('#aeon_request_selector_modal .modal-body').html(errorThrown + " - " + textStatus + " - " + jqXHR.responseText);
              }
          });
          }
          else{
            $.ajax({
            url: APP_PATH + 'aeon/aeon-request-popup',
            method: 'post',
            data: {
                uri: recordURI,
                request_type: requestType,
                finding_aid_view: exp.isFindAidView(),
            },
            success: function (html) {
                $('#aeon_request_selector_modal .modal-body').html(html);
                new AeonRequestForm(recordURI, $('#aeon_request_selector_modal .modal-body form'));
            },
            error: function (jqXHR, textStatus, errorThrown) {
                $('#aeon_request_selector_modal .modal-body').html(errorThrown);
            }
   
          });          

          }
    }

    const AeonRequestForm = function(recordURI, $form) {
        this.$form = $form;
        this.$modal = $form.closest('.modal');
        this.recordURI = recordURI;
        this.init();
    };

    AeonRequestForm.prototype.init = function() {
        const self = this;

        self.$form.on('click', '.aeon_select_all', function() {
            $('#aeonRequestTable').find('tbody .aeon_requestable_item_input:not(:checked)').trigger('click');
        });

        self.$form.on('click', '.aeon_clear_all', function() {
            $('#aeonRequestTable').find('tbody .aeon_requestable_item_input:checked').trigger('click');
        });

        self.$form.on('click', '.aeon_requestable_item_input', function() {
            self.refreshFormStatus();
        });

        self.$form.find('#request_type').on('change', function() {
            loadAeonRequestForm(self.recordURI, self.$form.find('#request_type').val());
        });

        self.$form.on('submit', function(event) {
            event.preventDefault();

            if (!self.$form.is(':disabled')) {
                $.ajax({
                    url: self.$form.attr('action'),
                    method: 'post',
                    data: new FormData(self.$form[0]),
                    processData: false,
                    contentType: false,
                    success: function(html) {
                        $('#aeonRequestFormWrapper').remove();
                        $(document.body).append('<div id="aeonRequestFormWrapper">');
                        $('#aeonRequestFormWrapper').html(html);
                        $('#aeonRequestFormWrapper form').submit();
                        self.$modal.modal('hide');
                    },
                    error: function(jqXHR, textStatus, errorThrown) {
                        $('#aeonFormSubmit').prop('disabled', false);
                        self.$modal.find('.modal-body').html(errorThrown);

                        if (jqXHR.responseText) {
                            self.$modal.find('.modal-body').append('<div>' + jqXHR.responseText + '</div>');
                        }
                    }
                });

                self.$form.find('#aeonFormSubmit').prop('disabled', true);
            }
        });

        if ($('#aeonRequestTable').find('tbody .aeon_requestable_item_input').length === 1) {
            $('#aeonRequestTable').find('tbody .aeon_requestable_item_input').prop('checked', true);
            self.refreshFormStatus();
        }
    }

    AeonRequestForm.prototype.refreshFormStatus = function() {
        const self = this;
        if (self.$form.find('table tbody .aeon_requestable_item_input:checked').length > 0) {
            self.$form.prop('disabled', false);
            self.$form.find('#aeonFormSubmit').prop('disabled', false);
        } else {
            self.$form.prop('disabled', true);
            self.$form.find('#aeonFormSubmit').prop('disabled', true);
        }
    };

    exp.AeonRequestForm = AeonRequestForm;
})(window);

$(document).ready(function() {
    $('#disabled-button-wrapper').tooltip({html:true});

    $(document.body).append($('#aeon_request_modal_template').html());
    


    $('.information > div > a').attr('id', 'aeon-request-button');
    var uri = $('.information > div > a').attr('link');
    var finding_aid_view = $('.information > div > a').attr('finding_aid_view');
    $(document).on('click', '#aeon-request-button', function() {
        $('#aeon_request_selector_modal .modal-body').empty();
        $('#aeon_request_selector_modal').modal('show');
        alert("URI: " + uri);
        loadAeonRequestForm(uri + " - " + finding_aid_view, '');
    });
});
