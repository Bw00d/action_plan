// Replace Rails's default confirm popup with our own version
$.rails.allowAction = function (link) {
    "use strict";
    if (link.data("confirm") == undefined) {
        return true;
    }
    $.rails.showConfirmationDialog(link);
    return false;
};

// User click confirm button. Rails UJS attaches different event
// handlers depending on element type — anchors / buttons respond to
// click.rails, forms respond to submit.rails. The original version
// only triggered click.rails, so confirmed form submissions (like the
// "Remove collaborator" form on the incident users page) silently did
// nothing after the user clicked Confirm. Also strip the data attr so
// retriggering doesn't re-prompt.
$.rails.confirmed = function (link) {
    "use strict";
    link.data("confirm", null);
    link.removeAttr("data-confirm");
    if (link.is("form")) {
        link.trigger("submit.rails");
    } else {
        link.trigger("click.rails");
    }
};

//  Display our version of the confirmation dialog
$.rails.showConfirmationDialog = function (link) {
    "use strict";
    var message = link.data("confirm");
    sweetAlert({
        title: message,
        type: "warning",
        confirmButtonText: "Confirm",
        // Do not confirm by pressing the Enter or Space, unless the user
        // manually focuses the confirm button.
        allowEnterKey: false,
        // Bootstrap "danger" class color
        confirmButtonColor: "#d9534f",
        showCancelButton: true
    }).then(function(e) {
        $.rails.confirmed(link);
    });
};
