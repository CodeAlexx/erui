
import os
import torch
import sys

# Ensure we can import from the project root
sys.path.append(os.getcwd())

from web_ui.backend.services.caption_service import CaptionService

def test_captioning():
    service = CaptionService.get_instance()
    
    # 1. Load Model (Use the one the user likely tried, or the default)
    print("Loading model...")
    # Using None (FP16/BF16) as requested
    service.load_model("Qwen/Qwen2.5-VL-7B-Instruct", quantization="None", attn_impl="eager")
    
    # 2. Find a test file
    test_dir = "/home/alex/sd3m_images/02_a_photos"
    test_file = None
    if os.path.exists(test_dir):
        for f in os.listdir(test_dir):
            if f.lower().endswith(('.png', '.jpg', '.jpeg')):
                test_file = os.path.join(test_dir, f)
                break
    
    if not test_file:
        print(f"No test file found in {test_dir}")
        return

    print(f"Testing with file: {test_file}")

    # 3. Generate Caption
    try:
        caption = service.generate_caption(test_file, "Describe this image.")
        print(f"SUCCESS! Caption: {caption}")
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"FAILED: {e}")

if __name__ == "__main__":
    test_captioning()
