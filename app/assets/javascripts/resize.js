$(document).on("turbolinks:load", function() {

// Resize image 

  $('.cover-image').click(function(){
    $('.resizer').toggle();
    $('resizer').toggle('.bordered')
  });

  /*Make resizable div by Hung Nguyen*/
  function makeResizableImage() {
    const resizables = document.querySelectorAll('.resizable');
    
    resizables.forEach(function(resizable) {
      const element = resizable.querySelector('.resizers');
      const resizers = resizable.querySelectorAll('.resizer');
      const blockDiv = resizable.closest('.block');
      const blockId = blockDiv ? blockDiv.id : null;
      const minimum_size = 20;
      let original_width = 0;
      let original_height = 0;
      let original_x = 0;
      let original_y = 0;
      let original_mouse_x = 0;
      let original_mouse_y = 0;
      
      for (let i = 0; i < resizers.length; i++) {
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
            const width = original_width - (e.pageX - original_mouse_x)
            if (width > minimum_size) {
              element.style.width = width + 'px'
            }
          }
          else if (currentResizer.classList.contains('top-right')) {
            const width = original_width + (e.pageX - original_mouse_x)
            if (width > minimum_size) {
              element.style.width = width + 'px'
            }
          }
          else {
            const width = original_width - (e.pageX - original_mouse_x)
            if (width > minimum_size) {
              element.style.width = width + 'px'
            }
          }
        }
        
        function stopResize() {
          window.removeEventListener('mousemove', resize_image)
          
          // Save the new dimensions
          if (blockId) {
            const newWidth = element.style.width;
            console.log('Block ID:', blockId, 'New width:', newWidth);
            
            // Try to find the form - check for both class names
            let form = $('#' + blockId + ' form.edit_block');
            if (form.length === 0) {
              // Try with underscore in class name
              form = $('#' + blockId + ' form[class*="edit_block"]');
            }
            
            console.log('Form found:', form.length > 0);
            
            if (form.length > 0) {
              // Update the width field value
              let widthField = form.find('input[name="block[image_width]"]');
              if (widthField.length > 0) {
                widthField.val(newWidth);
                console.log('Width field updated:', newWidth);
              }
              
              // Submit the form to save dimensions
              form.trigger('submit.rails');
              console.log('Form submitted');
            } else {
              console.error('No form found for block:', blockId);
            }
          }
        }
      }
    });
  }

  makeResizableImage()


// change padding on block

  $('.resize-padding').hover(function(){
    $('.resize-padding').removeClass('selected-resizer')
    $(this).addClass('selected-resizer');
  });

   /*Make resizable div by Hung Nguyen*/
  function makeResizableBlock(div) {
    const resizers = document.querySelectorAll(div + ' .resize-padding')
    const minimum_size = 0;
    let original_height = 0;
    let original_y = 0;
    let original_mouse_y = 0;
    for (let i = 0;i < resizers.length; i++) {
      const currentResizer = resizers[i];
      const parent = currentResizer.closest('.bottom-padding')
      currentResizer.addEventListener('mousedown', function(e) {
        e.preventDefault()
        original_height = parseFloat(getComputedStyle(parent, null).getPropertyValue('height').replace('px', ''));
        original_y = parent.getBoundingClientRect().top;
        original_mouse_y = e.pageY;
        window.addEventListener('mousemove', resize_block)
        window.addEventListener('mouseup', stopResize)
        // $('.block-form').trigger('submit.rails');
      })
      
      function resize_block(e) {
          const height = original_height + (e.pageY - original_mouse_y)

          if (height > minimum_size) {
            parent.style.height = height + 'px'
            // parent.previousElementSibling('#block_bottom_padding').val(height + 'px');
            $('input#block_bottom_padding').val(height + 'px');
          }
      }

      function stopResize() {
        window.removeEventListener('mousemove', resize_block)

        $('#edit_'+ $('.selected-resizer').parents('.block').attr("id")).trigger('submit.rails');
        // alert($('.selected-resizer').parents('.block').attr("id"))
        
      }
    }
  }

  makeResizableBlock('.bottom-padding')

  // Make split block images draggable horizontally
  function makeDraggableImages() {
    const splitBlocks = document.querySelectorAll('.split-block-wrapper .resizers');
    
    splitBlocks.forEach(function(resizer) {
      const blockDiv = resizer.closest('.block');
      const blockId = blockDiv ? blockDiv.id : null;
      let isDragging = false;
      let startX = 0;
      let startLeft = 0;
      
      // Add drag handle
      const dragHandle = document.createElement('div');
      dragHandle.className = 'drag-handle';
      dragHandle.innerHTML = '⋮⋮';
      dragHandle.title = 'Drag to reposition horizontally';
      resizer.appendChild(dragHandle);
      
      dragHandle.addEventListener('mousedown', function(e) {
        e.preventDefault();
        isDragging = true;
        startX = e.clientX;
        
        // Get current position
        const currentTransform = resizer.style.transform;
        const match = currentTransform.match(/translateX\(([-\d.]+)px\)/);
        startLeft = match ? parseFloat(match[1]) : 0;
        
        resizer.classList.add('dragging');
        
        window.addEventListener('mousemove', drag);
        window.addEventListener('mouseup', stopDrag);
      });
      
      function drag(e) {
        if (!isDragging) return;
        
        const deltaX = e.clientX - startX;
        const newLeft = startLeft + deltaX;
        
        // Limit movement to reasonable bounds
        const maxMove = 100; // pixels
        const limitedLeft = Math.max(-maxMove, Math.min(maxMove, newLeft));
        
        resizer.style.transform = `translateX(${limitedLeft}px)`;
      }
      
      function stopDrag(e) {
        if (!isDragging) return;
        isDragging = false;
        
        resizer.classList.remove('dragging');
        window.removeEventListener('mousemove', drag);
        window.removeEventListener('mouseup', stopDrag);
        
        // Save the new position
        if (blockId) {
          const finalTransform = resizer.style.transform;
          const match = finalTransform.match(/translateX\(([-\d.]+)px\)/);
          const positionX = match ? match[1] + 'px' : '0px';
          
          console.log('Saving position:', positionX, 'for block:', blockId);
          
          // Find the form and save position
          const form = $('#' + blockId + ' form[class*="edit_block"]');
          if (form.length > 0) {
            let positionField = form.find('input[name="block[image_position_x]"]');
            if (positionField.length === 0) {
              form.append('<input type="hidden" name="block[image_position_x]" />');
              positionField = form.find('input[name="block[image_position_x]"]');
            }
            positionField.val(positionX);
            
            // Submit the form
            form.trigger('submit.rails');
            console.log('Position saved');
          }
        }
      }
    });
  }
  
  // Initialize draggable images
  makeDraggableImages();

});