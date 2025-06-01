


$(function() {
  var setup_inline_request_form = function(uri) {
    $('#aeon_request_selector_modal').remove();
    $(document.body).append($('#aeon_request_modal_template').html());

    $('#aeon_request_selector_modal .modal-body').empty();
    $('#aeon_request_selector_modal').modal('show');

    loadAeonRequestForm(uri, '');
  };

  window.setup_inline_request_form = setup_inline_request_form;
});

function apply_request_buttons_to_infinite() {
  $('.infinite-item[data-requestable="true"]').each(function () {
    const section = $(this);

    section.find('.information').addClass('row');
    section.find('.information h3').addClass('col-sm-9');

    const requestButton = $('<div class="col-sm-3"></div>');
    const link = $('<a class="btn btn-default btn-sm" style="margin-bottom: 0.5em;" href="javascript:void(0);">' +
                   '<i class="fa fa-external-link fa-external-link-alt"></i> Request</a>');

    link.on('click', function () {
      setup_inline_request_form(section.data('uri'));
    });

    requestButton.append(link);

    // Only add if not already there
    if (section.find('.information .col-sm-3').length === 0) {
      section.find('.information').append(requestButton);
    }
  });
}


document.addEventListener("DOMContentLoaded", () => {
  const infiniteContainer = document.getElementById("infinite-records-container");
  if (!infiniteContainer) return;

  const applyOnce = () => {
    document.querySelectorAll('.infinite-record-record').forEach(el => {
      if (el.dataset.requestButtonApplied) return; // prevent reapplying
      el.dataset.requestButtonApplied = true;

      const info = el.querySelector('.infinite-item[data-requestable="true"] .information');
      if (info) {
        info.classList.add('row');
        const h3 = info.querySelector('h3');
        if (h3) h3.classList.add('col-sm-9');

        const requestButton = document.createElement('div');
        requestButton.className = 'col-sm-3';

        const link = document.createElement('a');
        link.className = 'btn btn-default btn-sm';
        link.style.marginBottom = '0.5em';
        link.href = 'javascript:void(0);';
        link.innerHTML = '<i class="fa fa-external-link fa-external-link-alt"></i> Request';

        link.addEventListener('click', () => {
          setup_inline_request_form(el.dataset.uri);
        });

        requestButton.appendChild(link);
        info.appendChild(requestButton);
      }
    });
  };

  const debouncedApply = debounce(applyOnce, 100);

  const observer = new MutationObserver((mutationsList) => {
    for (const mutation of mutationsList) {
      if (mutation.type === "childList" && mutation.addedNodes.length > 0) {
        debouncedApply();
      }
    }
  });

  observer.observe(infiniteContainer, { childList: true, subtree: true });

  setTimeout(applyOnce, 200); // slight delay to allow initial render
});

function debounce(func, wait) {
  let timeout;
  return function () {
    clearTimeout(timeout);
    timeout = setTimeout(func, wait);
  };
}
