$(document).on("turbolinks:load", function() {
  $('select#resource_category').change(function() {
    var text = $(this).val();
    $('#order-number-input').show();
    switch(text) {
    case 'EQUIPMENT':  
      var prefix = 'E-'
     break;

    case 'CREW':  
      var prefix = 'C-'
      break;

    case 'OVERHEAD':
      var prefix = 'O-'
      break;
    }
      $('.order-number-prefix').html( prefix )

  });
});