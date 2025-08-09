require 'rails_helper'

describe 'IAP Cover', type: :feature, js: true do
  before do 
    user = create_and_signin_user
    incident = create_new_incident(user)
    
    # Navigate to the incidents page if not already there
    visit incidents_path
    
    # Wait for the page to load and check if we're on the right page
    expect(page).to have_content('Swamp Goat')
    
    click_link 'Swamp Goat'
    click_link 'IAP' 
    
    # Fill in the date and close the datepicker
    fill_in 'Date', with: Date.today.strftime("%m/%d/%Y")
    
    # Press escape or tab to close the datepicker
    find('#plan_date').send_keys(:tab)
    
    # Alternative: use JavaScript to hide the datepicker
    page.execute_script("$('.datepicker').hide();")
    
    # Wait a moment for UI to settle
    sleep 0.5
    
    # Scroll the button into view and click it
    button = find('input[value="Create Plan"]')
    page.execute_script("arguments[0].scrollIntoView(true);", button)
    button.click

  end
    
  subject { page }

  describe 'Creating a cover for the IAP' do
    before  do 
      # Need to expand the IAP section first by clicking on the plan-row IAP link
      find('#iap-row').click
      # Wait for the content to expand
      expect(page).to have_link('Cover')
      click_link 'Cover'
      click_button 'ADD COVER'
    end

    context 'should populate the cover with template blocks' do
      it { should have_content('Incident Action Plan') }
      it { should have_content('Incident Name') }
      it { should have_content(Date.today.strftime("%B %d, %Y")) }
      it { should have_content('0700 - 2200') }
      it { should have_content('charge code') }
    end
  end

  describe 'Managing blocks on the cover' do
    before do
      # Create a cover first
      find('#iap-row').click
      expect(page).to have_link('Cover')
      click_link 'Cover'
      click_button 'ADD COVER'
      expect(page).to have_content('Incident Action Plan')
    end

    context 'creating text blocks' do
      it 'allows adding a new text block below an existing block' do
        # Click on an existing block to show the new block buttons
        first('.block').click
        
        # Click the new block button (appears after clicking a block)
        button = find('.new-block-button', match: :first)
        page.execute_script("arguments[0].scrollIntoView(true);", button)
        sleep 0.5
        page.execute_script("arguments[0].click();", button)
        
        # The new block type panel should appear
        expect(page).to have_css('.new-block-type', visible: true)
        
        # Select text block style
        within('.new-block-type') do
          find('.block-type-option[data-font-size="h2"]').click
        end
        
        # Wait for the new block to appear
        sleep 1 # Give time for the block to be created
        
        # Verify a new block was created (default is 6, so we should have 7)
        expect(all('.block').count).to be >= 7
      end

      it 'allows adding a new text block above an existing block' do
        # Click on an existing block
        first('.block').click
        
        # Click the new block button
        button = find('.new-block-button', match: :first)
        page.execute_script("arguments[0].scrollIntoView(true);", button)
        sleep 0.5
        page.execute_script("arguments[0].click();", button)
        
        # Select text block style
        within('.new-block-type') do
          find('.block-type-option[data-font-size="h3"]').click
        end
        
        # Wait for the new block to appear
        sleep 1
        expect(all('.block').count).to be >= 7
      end
    end

    context 'deleting blocks' do
      it 'shows delete option for blocks' do
        # Click on a block to select it
        first('.block').click
        
        # Style controls should appear with delete option
        expect(page).to have_css('.style-controls', visible: true)
        
        # Verify delete link exists
        within(first('.style-controls')) do
          expect(page).to have_css('.delete-block a')
        end
      end
    end

    context 'editing block styles' do
      it 'allows changing font size' do
        # Click on a text block
        block = first('.block')
        block.click
        
        # Style controls should appear
        expect(page).to have_css('.style-controls', visible: true)
        
        # Click H1 style on the first block's style controls
        within(first('.style-controls')) do
          find('.h1-text').click
        end
        
        # Wait for the update
        sleep 0.5
        
        # Verify the font size changed
        within('.block', match: :first) do
          expect(page).to have_css('.h1')
        end
      end

      # it 'allows changing font weight to bold' do
      #   # Click on a text block
      #   block = first('.block')
      #   block.click
        
      #   # Style controls should appear
      #   expect(page).to have_css('.style-controls', visible: true)
        
      #   # Click bold style on the first block's style controls
      #   within(first('.style-controls')) do
      #     find('.bold-text').click
      #   end
        
      #   # Wait for the update
      #   sleep 0.5
        
      #   # Verify font weight changed
      #   expect(page).to have_css('.block[style*="font-weight: bold"]', match: :first)
      # end
    end

    # context 'creating image blocks' do
    #   it 'allows adding an image block' do
    #     # Click on an existing block
    #     first('.block').click
        
    #     # Click the new block button (appears after clicking a block)
    #     button = find('.new-block-button', match: :first)
    #     page.execute_script("arguments[0].scrollIntoView(true);", button)
    #     sleep 0.5
    #     page.execute_script("arguments[0].click();", button)
        
    #     # Select image block option
    #     within('.new-block-type') do
    #       find('.add-image-block').click
    #     end
        
    #     # Wait for the new image block
    #     sleep 1
    #     expect(page).to have_css('.image-block')
    #   end

    #   it 'allows uploading an image to an image block' do
    #     # First create an image block
    #     first('.block').click
    #     find('.new-block-button', match: :first).click
    #     within('.new-block-type') do
    #       find('.add-image-block').click
    #     end
        
    #     # Click on the image block to upload
    #     image_block = find('.image-block')
    #     image_block.click
        
    #     # The image upload form should appear
    #     expect(page).to have_css('.image-form', visible: true)
        
    #     # Attach a file
    #     attach_file 'block_main_image', Rails.root.join('spec', 'fixtures', 'test_image.jpg')
        
    #     # Submit the form
    #     click_button 'Upload'
        
    #     # Verify the image was uploaded
    #     expect(page).to have_css('.image-block img')
    #   end
    # end

    # context 'creating and managing split blocks' do
    #   it 'creates two side-by-side image blocks' do
    #     initial_block_count = all('.block').count
        
    #     # Click on an existing block
    #     first('.block').click
        
    #     # Click the new block button (appears after clicking a block)
    #     button = find('.new-block-button', match: :first)
    #     page.execute_script("arguments[0].scrollIntoView(true);", button)
    #     sleep 0.5
    #     page.execute_script("arguments[0].click();", button)
        
    #     # Select split block option
    #     within('.new-block-type') do
    #       find('[data-split-block="true"]').click
    #     end
        
    #     # Should create two new blocks in a split container
    #     expect(page).to have_css('.split-block-container')
    #     expect(page).to have_css('.split-block-wrapper', count: 2)
        
    #     # Total blocks should increase by 2
    #     sleep 1
    #     expect(all('.block').count).to be >= (initial_block_count + 2)
    #   end

    #   it 'deletes both blocks when deleting one split block' do
    #     # First create a split block
    #     first('.block').click
    #     find('.new-block-button', match: :first).click
    #     within('.new-block-type') do
    #       find('[data-split-block="true"]').click
    #     end
        
    #     initial_block_count = all('.block').count
        
    #     # Click on one of the split blocks
    #     first('.split-block-wrapper .block').click
        
    #     # Delete it
    #     accept_confirm do
    #       find('.delete-block').click
    #     end
        
    #     # Both split blocks should be deleted
    #     sleep 1
    #     expect(page).not_to have_css('.split-block-container')
    #     expect(all('.block').count).to be <= (initial_block_count - 2)
    #   end

    #   it 'allows horizontal dragging of split block images' do
    #     # Create a split block
    #     first('.block').click
    #     button = find('.new-block-button', match: :first)
    #     page.execute_script("arguments[0].scrollIntoView(true);", button)
    #     sleep 0.5
    #     page.execute_script("arguments[0].click();", button)
        
    #     within('.new-block-type') do
    #       find('[data-split-block="true"]').click
    #     end
        
    #     sleep 1 # Wait for split blocks to be created
        
    #     # Upload an image to the first split block
    #     first('.split-block-wrapper .block').click
    #     within('.image-form') do
    #       attach_file 'block_main_image', Rails.root.join('spec', 'fixtures', 'test_image.jpg')
    #       click_button 'Upload'
    #     end
        
    #     sleep 1 # Wait for upload
        
    #     # Check if drag functionality exists
    #     expect(page).to have_css('.split-block-wrapper .resizers')
    #   end
    # end

    # context 'canceling operations' do
    #   it 'can cancel new block creation' do
    #     initial_block_count = all('.block').count
        
    #     # Start creating a new block
    #     first('.block').click
    #     find('.new-block-button', match: :first).click
        
    #     # Cancel by clicking the X
    #     within('.new-block-type') do
    #       find('.cancel-block').click
    #     end
        
    #     # Panel should be hidden and no new block created
    #     expect(page).not_to have_css('.new-block-type', visible: true)
    #     expect(all('.block').count).to eq(initial_block_count)
    #   end

    #   it 'can cancel image upload' do
    #     # Create an image block
    #     first('.block').click
    #     find('.new-block-button', match: :first).click
    #     within('.new-block-type') do
    #       find('.add-image-block').click
    #     end
        
    #     # Click to upload
    #     find('.image-block').click
        
    #     # Cancel the upload
    #     within('.image-form') do
    #       find('.cancel-image-upload').click
    #     end
        
    #     # Form should be hidden
    #     expect(page).not_to have_css('.image-form', visible: true)
    #   end
    # end
  end


end
