import cv2
import os

def extract_frames(video_path, output_dir, skip=1):
    """
    Extracts frames from a video, skipping a specified number of frames.

    Parameters:
    - video_path: Path to the input video file.
    - output_dir: Directory to save the extracted frames.
    - skip: Number of frames to skip (e.g., 1 means skip every other frame).
    """
    os.makedirs(output_dir, exist_ok=True)
    
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("Error: Cannot open video.")
        return

    frame_idx = 0
    saved_idx = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        if frame_idx % (skip + 1) == 0:
            filename = os.path.join(output_dir, f"frame_{saved_idx:05d}.png")
            cv2.imwrite(filename, frame)
            saved_idx += 1

        frame_idx += 1

    cap.release()
    print(f"Done. Extracted {saved_idx} frames to '{output_dir}'.")

# Example usage:
if __name__ == "__main__":
    extract_frames("input_video.mp4", "output_frames", skip=2)  # Change skip=1,2,3 as needed
