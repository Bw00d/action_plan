$(document).on("turbolinks:load", function() {

  $('.cover-image').click(function(){
    $('.resizer').toggle();
    $('resizer').toggle('.bordered')
  });

  /*Make resizable div by Hung Nguyen*/
  function makeResizableImage(div) {
    const element = document.querySelector(div + ' .resizers');
    const resizers = document.querySelectorAll(div + ' .resizer')
    const minimum_size = 20;
    let original_width = 0;
    let original_height = 0;
    let original_x = 0;
    let original_y = 0;
    let original_mouse_x = 0;
    let original_mouse_y = 0;
    for (let i = 0;i < resizers.length; i++) {
      const currentResizer = resizers[i];
      currentResizer.addEventListener('mousedown', function(e) {
        e.preventDefault()
        original_width = parseFloat(getComputedStyle(element, null).getPropertyValue('width').replace('px', ''));
        original_height = parseFloat(getComputedStyle(element, null).getPropertyValue('height').replace('px', ''));
        original_x = element.getBoundingClientRect().left;
        original_y = element.getBoundingClientRect().top;
        original_mouse_x = e.pageX;
        original_mouse_y = e.pageY;
        window.addEventListener('mousemove', resize_image)
        window.addEventListener('mouseup', stopResize)
      })
      
      function resize_image(e) {
        if (currentResizer.classList.contains('bottom-right')) {
          const width = original_width + (e.pageX - original_mouse_x);
          if (width > minimum_size) {
            element.style.width = width + 'px'
          }
          
        }
        else if (currentResizer.classList.contains('bottom-left')) {
          // const height = original_height + (e.pageY - original_mouse_y)
          const width = original_width - (e.pageX - original_mouse_x)
          // if (height > minimum_size) {
          //   element.style.height = height + 'px'
          // }
          if (width > minimum_size) {
            element.style.width = width + 'px'
            // element.style.left = original_x + (e.pageX - original_mouse_x) + 'px'
          }
        }
        else if (currentResizer.classList.contains('top-right')) {
          const width = original_width + (e.pageX - original_mouse_x)
          // const height = original_height - (e.pageY - original_mouse_y)
          if (width > minimum_size) {
            element.style.width = width + 'px'
          }
          // if (height > minimum_size) {
          //   element.style.height = height + 'px'
          //   element.style.top = original_y + (e.pageY - original_mouse_y) + 'px'
          // }
        }
        else {
          const width = original_width - (e.pageX - original_mouse_x)
          // const height = original_height - (e.pageY - original_mouse_y)
          if (width > minimum_size) {
            element.style.width = width + 'px'
            // element.style.left = original_x + (e.pageX - original_mouse_x) + 'px'
          }
          // if (height > minimum_size) {
          //   element.style.height = height + 'px'
          //   element.style.top = original_y + (e.pageY - original_mouse_y) + 'px'
          // }
        }
      }
      
      function stopResize() {
        window.removeEventListener('mousemove', resize_image)
      }
    }
  }

  makeResizableImage('.resizable')

  $('.resize-padding').hover(function(){
    $('.resize-padding').removeClass('selected-resizer')
    $(this).addClass('selected-resizer');
  });

   /*Make resizable div by Hung Nguyen*/
  function makeResizableBlock(div) {
    // const element = document.querySelector(div + ' .bottom-padding');
    const resizers = document.querySelectorAll(div + ' .resize-padding')
    const minimum_size = 0;
    // let original_width = 0;
    let original_height = 0;
    // let original_x = 0;
    let original_y = 0;
    // let original_mouse_x = 0;
    let original_mouse_y = 0;
    for (let i = 0;i < resizers.length; i++) {
      const currentResizer = resizers[i];
      const parent = currentResizer.closest('.bottom-padding')
      currentResizer.addEventListener('mousedown', function(e) {
        e.preventDefault()
        // original_width = parseFloat(getComputedStyle(element, null).getPropertyValue('width').replace('px', ''));
        original_height = parseFloat(getComputedStyle(parent, null).getPropertyValue('height').replace('px', ''));
        // original_x = parent.getBoundingClientRect().left;
        original_y = parent.getBoundingClientRect().top;
        // original_mouse_x = e.pageX;
        original_mouse_y = e.pageY;
        window.addEventListener('mousemove', resize_block)
        window.addEventListener('mouseup', stopResize)
      })
      
      function resize_block(e) {
          const height = original_height + (e.pageY - original_mouse_y)

          if (height > minimum_size) {
            parent.style.height = height + 'px'
          }
      }
      
      function stopResize() {
        window.removeEventListener('mousemove', resize_block)
      }
    }
  }

  makeResizableBlock('.bottom-padding')

});