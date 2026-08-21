# CDN uploads

The screenshot studio saves every image to `screenshots/` inside the resource.
Serving them through `nui://` means the whole folder ships to every client with
the resource download. Uploading them to a CDN avoids that: the UI loads the
images over HTTP instead, and the screenshots no longer need to be streamed to
clients at all.

## Server config — `config/server.lua`

```lua
imageUpload = {
    provider = 'qbox', -- 'qbox', 'fivemanage', 'fivemerr' or 'custom'
    apiKey = 'YOUR_API_KEY', -- leave '' to disable uploads
    autoUpload = false, -- upload every shot as it is saved

    custom = { -- only used with provider = 'custom'
        url = '',
        field = 'file',
        responsePath = 'data.url',
    },
},
```

| Provider | Get a key | Deletes superseded files |
| --- | --- | --- |
| `qbox` | [Qbox CDN dashboard](https://docs.qbox.re/dashboard/cdn) | yes |
| `fivemanage` | [Fivemanage dashboard](https://docs.fivemanage.com) | yes |
| `fivemerr` | [Fivemerr dashboard](https://docs.fivemerr.com) | no delete API |

The key stays server-side; it is never sent to clients or the NUI.

### Custom CDN

Any host that accepts a multipart POST with an `Authorization` header and
returns JSON containing the public URL works. Set `provider = 'custom'` and
fill the `custom` block:

- `url` — the upload endpoint, receives `POST` with the file in a form field
- `field` — the multipart form field name the host expects (usually `file`)
- `responsePath` — dot path to the URL inside the JSON response
  (e.g. `data.url` for `{ "data": { "url": "https://..." } }`)
- `storagePath` — optional dot path to the id/path the host needs for deletion
- `deleteUrl` — optional delete endpoint; `%s` is replaced with the stored id.
  With both set, re-uploading a re-shot image deletes the superseded CDN copy.

## Uploading

- **`autoUpload = true`** — every screenshot is queued for upload the moment
  the studio saves it. Uploads run in a background queue on the server and
  never slow the capture pace; failures are logged to the server console.
- **`autoUpload = false`** — the studio panel shows an **Upload to CDN**
  button (only when a provider and key are configured). It uploads every file
  on disk that has not been uploaded yet, in the background, and notifies when
  it finishes. Progress is printed to the server console every 100 files.

Either way, uploads are incremental: a file that is already on the CDN is
never uploaded twice. The mapping of local file → CDN URL is kept in
`screenshots/_cdn.json`.

## Using the CDN in the UI — `config/shared.lua`

```lua
imageSource = 'cdn', -- 'local' | 'cdn'
```

With `'cdn'`, the appearance editor and the clothing-item thumbnails
(ox_inventory metadata `imageurl`) use the uploaded URLs. Any image that has
no uploaded copy yet falls back to the local `nui://` path automatically, so a
partial upload never breaks the UI.

Once everything is uploaded and `imageSource = 'cdn'` is live, the
`screenshots/**` entries in `fxmanifest.lua` `files {}` can be removed so
clients stop downloading the images with the resource.

## Re-shooting

With `autoUpload = true`, a re-shot image is re-uploaded, its URL refreshed,
and the superseded CDN copy deleted (on providers with a delete API). With
manual uploads, **Upload to CDN** skips files that were already uploaded —
after re-shooting items, delete their entries from `screenshots/_cdn.json`
(or the whole file) and run it again; superseded copies are deleted the same
way when the new upload replaces them.
