package com.gitcs.davaindia.ff

import androidx.core.content.FileProvider

/** Shares downloaded update APKs with the system installer. Its own class so it can't clash with plugins' providers. */
class UpdateFileProvider : FileProvider()
