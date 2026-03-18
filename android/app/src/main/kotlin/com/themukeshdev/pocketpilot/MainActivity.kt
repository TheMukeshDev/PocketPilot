package com.themukeshdev.pocketpilot

import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"pocketpilot/platform"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getGoogleSignInConfig" -> {
					val defaultWebClientId = getStringResource("default_web_client_id")
					result.success(
						mapOf(
							"isConfigured" to !defaultWebClientId.isNullOrBlank(),
							"defaultWebClientId" to defaultWebClientId,
							"packageName" to packageName,
						)
					)
				}

				"launchUpiIntent" -> {
					val uri = call.argument<String>("uri")
					val packageName = call.argument<String>("packageName")
					result.success(launchUpiIntent(uri, packageName))
				}

				"getAvailableUpiApps" -> {
					result.success(getAvailableUpiApps())
				}

				else -> result.notImplemented()
			}
		}
	}

	private fun launchUpiIntent(uriString: String?, packageName: String?): Boolean {
		if (uriString.isNullOrBlank()) {
			// Log: URI is null or blank
			return false
		}

		return try {
			val uri = Uri.parse(uriString)
			// Log: Created URI from string

			val intent = Intent(Intent.ACTION_VIEW, uri).apply {
				addCategory(Intent.CATEGORY_DEFAULT)
				addCategory(Intent.CATEGORY_BROWSABLE)
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				if (!packageName.isNullOrBlank()) {
					// Log: Setting package to $packageName
					setPackage(packageName)
				}
			}

			val launchIntent = if (packageName.isNullOrBlank()) {
				// Log: Creating chooser
				Intent.createChooser(intent, "Pay with")
			} else {
				intent
			}

			// Log: Starting activity with intent
			startActivity(launchIntent)
			true
		} catch (e: ActivityNotFoundException) {
			// Log: ActivityNotFoundException - ${e.message}
			false
		} catch (e: Exception) {
			// Log: Exception in launchUpiIntent - ${e.javaClass.simpleName}: ${e.message}
			false
		}
	}

	private fun getAvailableUpiApps(): List<Map<String, String>> {
		val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
		intent.addCategory(Intent.CATEGORY_DEFAULT)
		intent.addCategory(Intent.CATEGORY_BROWSABLE)

		val packageManager = packageManager
		val resolves = packageManager.queryIntentActivities(intent, 0)

		return resolves.mapNotNull { resolveInfo ->
			val activityInfo = resolveInfo.activityInfo ?: return@mapNotNull null
			val packageName = activityInfo.packageName ?: return@mapNotNull null
			val name = resolveInfo.loadLabel(packageManager)?.toString()?.trim().orEmpty()
			if (name.isBlank()) {
				return@mapNotNull null
			}

			val iconDrawable = try {
				resolveInfo.loadIcon(packageManager)
			} catch (_: Exception) {
				null
			} ?: return@mapNotNull null

			val icon = drawableToBase64(iconDrawable)
			if (icon.isBlank()) {
				return@mapNotNull null
			}

			mapOf(
				"name" to name,
				"packageName" to packageName,
				"icon" to icon,
			)
		}
	}

	private fun drawableToBase64(drawable: Drawable): String {
		val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
			drawable.bitmap
		} else {
			val size = 96
			val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
			val canvas = Canvas(bmp)
			drawable.setBounds(0, 0, canvas.width, canvas.height)
			drawable.draw(canvas)
			bmp
		}

		val output = ByteArrayOutputStream()
		bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
		return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
	}

	private fun getStringResource(name: String): String? {
		val resourceId = resources.getIdentifier(name, "string", packageName)
		if (resourceId == 0) {
			return null
		}

		return try {
			getString(resourceId)
		} catch (_: Exception) {
			null
		}
	}
}
