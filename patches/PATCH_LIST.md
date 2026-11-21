# Ani-Driver Patch Series

- **Upstream Source:** `bmdhacks/malisx2` (Nov 19–20, 2026 series, patches `0001`–`0010`)
- **Primary Test Target:** Mali-G52 MC2 (`v7` / Bifrost, Vulkan 1.1)

## Upstream `malisx2` Patches (`0001–0099`)

| # | Patch File | Target Files | v7 Impact | Summary |
| :--- | :--- | :--- | :--- | :--- |
| 0001 | `0001-Four-Vulkan-1.3-extensions-that-need-nothing-more-on.patch` | `src/vk/mali_physical_device.c` | Enabled | Enable `VK_KHR_copy_commands2`, `VK_EXT_tooling_info`, `VK_KHR_shader_non_semantic_info`, `VK_EXT_texel_buffer_alignment` |
| 0002 | `0002-The-features-Vulkan-1.2-requires.patch` | `src/vk/mali_buffer.c`, `src/vk/mali_physical_device.c` | Partial | Expose Vulkan 1.2 features/limits and return `0` for opaque capture addresses |
| 0003 | `0003-Vulkan-1.3-on-v10-v11-and-v12.patch` | `src/vk/mali_physical_device.c`, `src/vk/mali_vk.h` | None (JM=1.1) | Report Vulkan 1.3 on CSF arches (`v10–v12`), `1.1` on JM |
| 0004 | `0004-v9-the-shader-features-Vulkan-1.3-requires-and-mirro.patch` | `src/vk/mali_physical_device.c` | Mirror clamp | Add Vulkan 1.3 shader features on `v9` and mirror-clamp-to-edge helper |
| 0005 | `0005-Vulkan-1.3-on-v9.patch` | `src/vk/mali_physical_device.c`, `src/vk/mali_vk.h` | Stays 1.1 | Promote `v9` to Vulkan 1.3 while keeping `v7` on `1.1` |
| 0006 | `0006-v9-clip-distances.patch` | `src/vk/mali_physical_device.c`, `src/vk/mali_pipeline.c`, `src/vk/mali_shader.c`, `src/vk/mali_shader.h` | Minimal | Enable clip/cull distances on `v9` and unify clip/cull distance handling |
| 0007 | `0007-v9-null-buffers-and-buffer-views-read-as-empty-buffe.patch` | `src/vk/mali_descriptor_set.c` | None (`v9+`) | Map null buffers/buffer views to size-0 empty buffer at `MALI_NULL_BUFFER_ADDR` on `v9+` |
| 0008 | `0008-nullDescriptor-on-v9-to-v12.patch` | `src/vk/mali_physical_device.c` | Off (`v9–v12`) | Enable `VK_EXT_robustness2` / `VK_KHR_robustness2` (`nullDescriptor`) on `v9–v12` |
| 0009 | `0009-vkCmdExecuteCommands-is-the-stub-not-Mesa-s-common-r.patch` | `src/vk/mali_device.c` | Enabled | Route `vkCmdExecuteCommands` to `mali_waist_CmdExecuteCommands` stub |
| 0010 | `0010-No-image-features-for-formats-with-a-3-6-or-12-byte-.patch` | `src/vk/mali_format_table.c` | Enabled | Exclude 3, 6, and 12-byte non-compressed texels (`RGB8`, `RGB16`, `RGB32`) from image format features |

## Custom `ani-driver` Patches (`0100+`)

| # | Patch File | Category | Status | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| 0100 | *TBD* | Diagnostics / Batching | Planned | Custom `ani-driver` patches (`ani_diag.py` / batching experiments) |
