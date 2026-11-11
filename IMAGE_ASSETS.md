# CUE product photography

The product catalog uses 140 separate AI-generated studio photographs, one per product ID. They are representative product images, not manufacturer-supplied photographs or proof of a brand's exact construction. Product detail pages identify the images as AI-generated. Replace them with your own verified inventory photography before selling physical goods.

Generation method: built-in image generation tool. No external image API key or image-search downloads were used.

Final project asset folder: `assets/photos/`. Filenames match the stable product IDs in `lib/data/products.json`. Each source image is encoded as JPEG at quality 90 without changing the generated framing or resolution, to keep the offline application bundle manageable. Original PNGs are retained outside the app in the workspace's intermediate assets and in the generation tool's output folder.

Prompt set: `PHOTO_PROMPTS.json` records the product-specific prompt set. The common direction is realistic studio catalog photography, neutral seamless backgrounds, soft contact shadows, accurate materials, fully framed equipment, and no manufacturer logos, illustration, cartoon, or watermark.

The app icon is a code-generated billiards mark. Category navigation uses Material icons. Neither is a product photograph.
