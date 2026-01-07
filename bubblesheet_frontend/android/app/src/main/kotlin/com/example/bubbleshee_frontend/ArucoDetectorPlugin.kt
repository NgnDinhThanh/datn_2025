package com.example.bubbleshee_frontend

import org.opencv.calib3d.Calib3d
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Scalar
import org.opencv.core.CvType
import org.opencv.core.Core
import org.opencv.core.Size
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.media.MediaActionSound
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.content.Context
import android.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.objdetect.ArucoDetector
import org.opencv.objdetect.Dictionary
import org.opencv.objdetect.DetectorParameters
import org.opencv.objdetect.Objdetect
import java.io.File
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.min

class ArucoDetectorPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var mediaActionSound: MediaActionSound? = null
    
    // Corner marker IDs (4 corners of the answer sheet)
    private val CORNER_IDS = setOf(1, 5, 9, 10)
    
    // Constants for ID and answer detection
    private val MIN_ID_PIXELS = mapOf(
        "student" to 700,
        "quiz" to 600,
        "class" to 600
    )
    
    // Colors for annotated image (BGR format for OpenCV)
    // ZipGrade style: Green = correct, Red = wrong, Yellow = show correct answer
    private val COLOR_CORRECT = Scalar(0.0, 255.0, 0.0)   // Green - correct answer
    private val COLOR_WRONG = Scalar(0.0, 0.0, 255.0)     // Red - wrong answer
    private val COLOR_SHOW_CORRECT = Scalar(0.0, 255.0, 255.0) // Yellow - show correct answer (when wrong or blank)
    
    private companion object {
        private const val MIN_ANSWER_PIXELS = 1200
        private const val TAG = "ArucoDetector"
        
        /**
         * Safely extract [x, y] position from any data structure
         * Handles various types that may come from Flutter method channel:
         * - List<*> (ArrayList<Int>, ArrayList<Double>, etc.)
         * - Array<*>
         */
        fun getPosition(data: Any?): Pair<Double, Double>? {
            if (data == null) return null
            
            return when (data) {
                is List<*> -> {
                    if (data.size >= 2) {
                        val x = (data[0] as? Number)?.toDouble() ?: return null
                        val y = (data[1] as? Number)?.toDouble() ?: return null
                        Pair(x, y)
                    } else null
                }
                is Array<*> -> {
                    if (data.size >= 2) {
                        val x = (data[0] as? Number)?.toDouble() ?: return null
                        val y = (data[1] as? Number)?.toDouble() ?: return null
                        Pair(x, y)
                    } else null
                }
                else -> null
            }
        }
        
        /**
         * Safely extract position [x, y] from map with "position" key
         */
        fun getBubblePosition(map: Map<String, Any>): Pair<Double, Double>? {
            return getPosition(map["position"])
        }
        
        /**
         * Safely extract radius from bubble data
         */
        fun getBubbleRadius(bubble: Map<String, Any>): Int? {
            val radius = bubble["radius"] ?: return null
            return (radius as? Number)?.toInt()
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "aruco_detector")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        
        // Initialize MediaActionSound for camera shutter sound
        try {
            mediaActionSound = MediaActionSound()
            mediaActionSound?.load(MediaActionSound.SHUTTER_CLICK)
        } catch (e: Exception) {
            android.util.Log.e("ArucoDetector", "MediaActionSound init error: ${e.message}")
        }
        
        // Initialize OpenCV
        // Với static initialization, OpenCV sẽ được load tự động khi app start
        // Nếu dùng OpenCV Manager, cần init khác
        try {
            if (!OpenCVLoader.initLocal()) {
                // OpenCV initialization failed
                // Check:
                // 1. Native libraries đã được copy vào jniLibs chưa?
                // 2. opencv.jar đã được include trong dependencies chưa?
                // 3. Architecture của device có match với native libs không?
                android.util.Log.e("ArucoDetector", "OpenCV initialization failed")
            } else {
                android.util.Log.d("ArucoDetector", "OpenCV initialized successfully")
            }
        } catch (e: Exception) {
            android.util.Log.e("ArucoDetector", "OpenCV initialization error: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "detectMarkers" -> {
//                android.util.Log.d("ArucoDetector", "detectMarkers called")
                val imagePath = call.argument<String>("imagePath")
                val arucoType = call.argument<String>("arucoType") ?: "DICT_4X4_50"
                val cornerIds = call.argument<List<Int>>("cornerIds") ?: listOf(1, 5, 9, 10)
                
                if (imagePath == null) {
                    android.util.Log.e("ArucoDetector", "imagePath is null")
                    result.error("INVALID_ARGUMENT", "imagePath is required", null)
                    return
                }
                
//                android.util.Log.d("ArucoDetector", "Detecting markers in: $imagePath")
                try {
                    val detectionResult = detectArucoMarkers(imagePath, arucoType, cornerIds)
                    android.util.Log.d("ArucoDetector", "Detection successful: ready=${detectionResult["ready"]}, markers=${detectionResult["markersNorm"]}")
                    result.success(detectionResult)
                } catch (e: Exception) {
                    android.util.Log.e("ArucoDetector", "Detection failed: ${e.message}", e)
                    result.error("DETECTION_FAILED", e.message, null)
                }
            }
            "scanAnswerSheet" -> {
                val imagePath = call.argument<String>("imagePath")
                val template = call.argument<Map<String, Any>>("template")
                
                if (imagePath == null || template == null) {
                    result.error("INVALID_ARGUMENT", "imagePath and template are required", null)
                    return
                }
                
                android.util.Log.d(TAG, "scanAnswerSheet called with imagePath: $imagePath")
                
                try {
                    val scanResult = scanAnswerSheet(imagePath, template)
                    android.util.Log.d(TAG, "scanAnswerSheet success: ${scanResult["success"]}")
                    result.success(scanResult)
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "scanAnswerSheet failed: ${e.message}", e)
                    result.error("SCAN_FAILED", e.message, null)
                }
            }
            "createAnnotatedImage" -> {
                // Create annotated image with grading results (correct/wrong colors)
                val warpedImageBase64 = call.argument<String>("warpedImageBase64")
                val template = call.argument<Map<String, Any>>("template")
                val studentAnswers = call.argument<Map<String, Any>>("studentAnswers")
                val correctAnswers = call.argument<Map<String, Any>>("correctAnswers")
                
                if (warpedImageBase64 == null || template == null || studentAnswers == null || correctAnswers == null) {
                    result.error("INVALID_ARGUMENT", "All parameters are required", null)
                    return
                }
                
                try {
                    val annotatedBase64 = createAnnotatedImage(warpedImageBase64, template, studentAnswers, correctAnswers)
                    result.success(mapOf("annotated_image_base64" to annotatedBase64))
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "createAnnotatedImage failed: ${e.message}", e)
                    result.error("ANNOTATION_FAILED", e.message, null)
                }
            }
            "playShutterSound" -> {
                // Play camera shutter sound + vibration
                try {
                    // Play shutter sound
                    mediaActionSound?.play(MediaActionSound.SHUTTER_CLICK)
                    
                    // Vibrate
                    val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                        vibratorManager.defaultVibrator
                    } else {
                        @Suppress("DEPRECATION")
                        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(100)
                    }
                    
                    result.success(true)
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "playShutterSound failed: ${e.message}", e)
                    result.success(false)
                }
            }
            else -> {
                android.util.Log.w("ArucoDetector", "Unknown method: ${call.method}")
                result.notImplemented()
            }
        }
    }

    private fun detectArucoMarkers(
        imagePath: String,
        arucoType: String,
        cornerIds: List<Int>
    ): Map<String, Any> {
        // Check OpenCV initialization
        if (!OpenCVLoader.initLocal()) {
            throw Exception("OpenCV not initialized. Please check OpenCV setup.")
        }
        
        // Load image
        val file = File(imagePath)
        if (!file.exists()) {
            throw Exception("Image file not found: $imagePath")
        }
        
        val bitmap = BitmapFactory.decodeFile(imagePath)
        if (bitmap == null) {
            throw Exception("Failed to decode image: $imagePath")
        }

        val mat = Mat()
        Utils.bitmapToMat(bitmap, mat)

// Convert RGBA to BGR first (bitmap from Android is RGBA)
        val bgrMat = Mat()
        Imgproc.cvtColor(mat, bgrMat, Imgproc.COLOR_RGBA2BGR)
        mat.release()

// Convert to grayscale
        val gray = Mat()
        Imgproc.cvtColor(bgrMat, gray, Imgproc.COLOR_BGR2GRAY)
        bgrMat.release()

// Apply preprocessing (similar to backend)
        val blurred = Mat()
        Imgproc.GaussianBlur(gray, blurred, Size(5.0, 5.0), 0.0)
        
        // CLAHE (Contrast Limited Adaptive Histogram Equalization)
        val clahe = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
        val enhanced = Mat()
        clahe.apply(blurred, enhanced)
        
        // Get ArUco dictionary
        val dictionary = getArucoDictionary(arucoType)
        val parameters = DetectorParameters()
        val detector = ArucoDetector(dictionary, parameters)
        
        // Detect markers
        val markerCorners = mutableListOf<Mat>()
        val markerIds = Mat()
        val rejectedImgPoints = mutableListOf<Mat>()
        detector.detectMarkers(enhanced, markerCorners, markerIds, rejectedImgPoints)
        
        // Debug log
        android.util.Log.d("ArucoDetector", "Image size: ${enhanced.cols()}x${enhanced.rows()}")
        android.util.Log.d("ArucoDetector", "Markers found: ${markerIds.rows()}")
        
        // Process results
        val markersNorm = mutableListOf<Map<String, Any>>()
        val detectedIds = mutableSetOf<Int>()
        
        if (markerIds.rows() > 0) {
            val ids = IntArray(markerIds.rows().toInt())
            markerIds.get(0, 0, ids)
            android.util.Log.d("ArucoDetector", "Detected IDs: ${ids.toList()}")

            val exif = ExifInterface(imagePath)
            val orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
            for (i in ids.indices) {
                val id = ids[i]
                detectedIds.add(id)
                
                // Calculate center from corners
                // markerCorners[i] is a Mat with shape (4, 1, CV_32FC2) or (1, 4, CV_32FC2)
                // Each corner is a Point2f (x, y)
                val corners = markerCorners[i]
                
                // Read corners data - corners is CV_32FC2 (2 channels: x, y)
                val cornersData = FloatArray(corners.rows() * corners.cols() * 2)
                corners.get(0, 0, cornersData)
                
                // Calculate center: average of all 4 corners
                var sumX = 0.0
                var sumY = 0.0
                val numPoints = corners.rows() * corners.cols()
                for (j in 0 until numPoints) {
                    sumX += cornersData[j * 2].toDouble()
                    sumY += cornersData[j * 2 + 1].toDouble()
                }
                val centerX = sumX / numPoints
                val centerY = sumY / numPoints
                
                // Normalize coordinates (0.0 - 1.0)
                val normX = centerX / gray.cols().toDouble()
                val normY = centerY / gray.rows().toDouble()

                val (finalX, finalY) = when (orientation) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> Pair(1.0 - normY, normX)
                    ExifInterface.ORIENTATION_ROTATE_180 -> Pair(1.0 - normX, 1.0 - normY)
                    ExifInterface.ORIENTATION_ROTATE_270 -> Pair(normY, 1.0 - normX)
                    else -> Pair(normX, normY)
                }

                markersNorm.add(mapOf(
                    "id" to id,
                    "x" to finalX,
                    "y" to finalY
                ))
            }
        }
        
        // Check if ALL 4 corner markers are detected (required for perspective warp)
        // ZipGrade style: only ready when all 4 corners are visible
        val ready = CORNER_IDS.all { it in detectedIds }
        
        // Cleanup (mat và bgrMat đã release ở trên)
        gray.release()
        blurred.release()
        enhanced.release()
        markerIds.release()
        markerCorners.forEach { it.release() }
        rejectedImgPoints.forEach { it.release() }
        
        return mapOf(
            "ready" to ready,
            "markersNorm" to markersNorm
        )
    }
    
    private fun getArucoDictionary(type: String): Dictionary {
        val dictType = when (type) {
            "DICT_4X4_50" -> Objdetect.DICT_4X4_50
            "DICT_4X4_100" -> Objdetect.DICT_4X4_100
            "DICT_4X4_250" -> Objdetect.DICT_4X4_250
            "DICT_4X4_1000" -> Objdetect.DICT_4X4_1000
            "DICT_5X5_50" -> Objdetect.DICT_5X5_50
            "DICT_5X5_100" -> Objdetect.DICT_5X5_100
            "DICT_5X5_250" -> Objdetect.DICT_5X5_250
            "DICT_5X5_1000" -> Objdetect.DICT_5X5_1000
            "DICT_6X6_50" -> Objdetect.DICT_6X6_50
            "DICT_6X6_100" -> Objdetect.DICT_6X6_100
            "DICT_6X6_250" -> Objdetect.DICT_6X6_250
            "DICT_6X6_1000" -> Objdetect.DICT_6X6_1000
            "DICT_7X7_50" -> Objdetect.DICT_7X7_50
            "DICT_7X7_100" -> Objdetect.DICT_7X7_100
            "DICT_7X7_250" -> Objdetect.DICT_7X7_250
            "DICT_7X7_1000" -> Objdetect.DICT_7X7_1000
            "DICT_ARUCO_ORIGINAL" -> Objdetect.DICT_ARUCO_ORIGINAL
            else -> Objdetect.DICT_4X4_50
        }
        return Objdetect.getPredefinedDictionary(dictType)
    }
    
    /**
     * Full client-side scanning pipeline
     * 1. Detect ArUco markers
     * 2. Warp image to template coordinates
     * 3. Read Student ID, Quiz ID, Class ID
     * 4. Read answer bubbles
     * 5. Create annotated image
     */
    @Suppress("UNCHECKED_CAST")
    private fun scanAnswerSheet(
        imagePath: String,
        template: Map<String, Any>
    ): Map<String, Any?> {
        val startTime = System.currentTimeMillis()
        
        // Check OpenCV initialization
        if (!OpenCVLoader.initLocal()) {
            return mapOf(
                "success" to false,
                "error" to "OpenCV not initialized"
            )
        }
        
        // Load image
        val file = File(imagePath)
        if (!file.exists()) {
            return mapOf(
                "success" to false,
                "error" to "Image file not found: $imagePath"
            )
        }
        
        val bitmap = BitmapFactory.decodeFile(imagePath)
        if (bitmap == null) {
            return mapOf(
                "success" to false,
                "error" to "Failed to decode image"
            )
        }
        
        val originalMat = Mat()
        Utils.bitmapToMat(bitmap, originalMat)
        
        // Convert to BGR (OpenCV uses BGR)
        val bgrMat = Mat()
        Imgproc.cvtColor(originalMat, bgrMat, Imgproc.COLOR_RGBA2BGR)
        originalMat.release()
        
        // Convert to grayscale
        val gray = Mat()
        Imgproc.cvtColor(bgrMat, gray, Imgproc.COLOR_BGR2GRAY)
        
        // Preprocess for ArUco detection
        val blurred = Mat()
        Imgproc.GaussianBlur(gray, blurred, Size(5.0, 5.0), 0.0)
        val clahe = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
        val enhanced = Mat()
        clahe.apply(blurred, enhanced)
        blurred.release()
        
        // Detect ArUco markers
        val dictionary = getArucoDictionary("DICT_4X4_50")
        val parameters = DetectorParameters()
        val detector = ArucoDetector(dictionary, parameters)
        
        val markerCorners = mutableListOf<Mat>()
        val markerIds = Mat()
        val rejectedImgPoints = mutableListOf<Mat>()
        detector.detectMarkers(enhanced, markerCorners, markerIds, rejectedImgPoints)
        enhanced.release()
        
        // Build marker position map
        val detectedMarkers = mutableMapOf<Int, Point>()
        if (markerIds.rows() > 0) {
            val ids = IntArray(markerIds.rows())
            markerIds.get(0, 0, ids)
            
            for (i in ids.indices) {
                val id = ids[i]
                val corners = markerCorners[i]
                val cornersData = FloatArray(corners.rows() * corners.cols() * 2)
                corners.get(0, 0, cornersData)
                
                // Calculate center
                var sumX = 0.0
                var sumY = 0.0
                val numPoints = corners.rows() * corners.cols()
                for (j in 0 until numPoints) {
                    sumX += cornersData[j * 2].toDouble()
                    sumY += cornersData[j * 2 + 1].toDouble()
                }
                detectedMarkers[id] = Point(sumX / numPoints, sumY / numPoints)
            }
        }
        
        // Cleanup
        markerIds.release()
        markerCorners.forEach { it.release() }
        rejectedImgPoints.forEach { it.release() }
        
        // Check if all 4 corner markers are detected
        val missingMarkers = CORNER_IDS.filter { it !in detectedMarkers.keys }
        if (missingMarkers.isNotEmpty()) {
            gray.release()
            bgrMat.release()
            return mapOf(
                "success" to false,
                "error" to "Missing ArUco markers: $missingMarkers. Detected: ${detectedMarkers.keys}"
            )
        }
        
        // Get template markers
        val templateMarkers = template["aruco_marker"] as? List<Map<String, Any>>
        if (templateMarkers == null) {
            gray.release()
            bgrMat.release()
            return mapOf(
                "success" to false,
                "error" to "Template missing aruco_marker data"
            )
        }
        
        // Build template marker position map
        val templatePositions = mutableMapOf<Int, Point>()
        for (marker in templateMarkers) {
            val id = (marker["id"] as? Number)?.toInt() ?: continue
            val pos = getPosition(marker["position"]) ?: continue
            templatePositions[id] = Point(pos.first, pos.second)
        }
        
        // Warp image to template
        val warpResult = warpToTemplate(bgrMat, detectedMarkers, templatePositions, template)
        bgrMat.release()
        gray.release()
        
        if (warpResult == null) {
            return mapOf(
                "success" to false,
                "error" to "Failed to warp image to template"
            )
        }
        
        val warped = warpResult.first
        val warpedGray = warpResult.second
        
        // Read IDs
        val studentIdSection = template["student_id_section"] as? Map<String, Any>
        val quizIdSection = template["quiz_id_section"] as? Map<String, Any>
        val classIdSection = template["class_id_section"] as? Map<String, Any>
        
        val studentIdDigits = if (studentIdSection != null) 
            readIdSection(warped, warpedGray, studentIdSection, "student") else emptyList()
        val quizIdDigits = if (quizIdSection != null) 
            readIdSection(warped, warpedGray, quizIdSection, "quiz") else emptyList()
        val classIdDigits = if (classIdSection != null) 
            readIdSection(warped, warpedGray, classIdSection, "class") else emptyList()
        
        // Read answers and draw on annotated image
        val answerArea = template["answer_area"] as? Map<String, Any>
        val questions = answerArea?.get("questions") as? List<Map<String, Any>> ?: emptyList()
        
        // Create annotated image (copy of warped) - do this BEFORE reading answers
        // so we can draw on it while reading
        val annotated = warped.clone()
        
        val answersRaw = mutableMapOf<String, Int>()
        var blankCount = 0
        var multipleMarks = 0
        
        for (question in questions) {
            val qNum = (question["question"] as? Number)?.toInt() ?: continue
            val bubbles = question["bubbles"] as? List<Map<String, Any>> ?: continue
            
            val (selected, isMultiple) = detectMarkedBubbleAndDrawWithMultiple(warpedGray, annotated, bubbles, MIN_ANSWER_PIXELS)
            answersRaw[(qNum - 1).toString()] = selected // 0-based index for key
            
            if (selected == -1) blankCount++
            if (isMultiple) multipleMarks++
        }
        
        // Draw student ID, quiz ID, class ID highlights (green circles on selected bubbles)
        // Already done in readIdSection
        
        // Crop info section (contains student ID, quiz ID, class ID bubbles)
        val infoSectionBase64 = cropInfoSection(annotated, template)
        
        // Encode images to base64
        val warpedBase64 = encodeImageToBase64(warped)
        val annotatedBase64 = encodeImageToBase64(annotated)
        
        // Cleanup
        warped.release()
        warpedGray.release()
        annotated.release()
        
        val elapsedTime = System.currentTimeMillis() - startTime
        
        return mapOf(
            "success" to true,
            "student_id_digits" to studentIdDigits,
            "quiz_id_digits" to quizIdDigits,
            "class_id_digits" to classIdDigits,
            "answers_raw" to answersRaw,
            "total_questions" to questions.size,
            "blank_count" to blankCount,
            "multiple_marks" to multipleMarks,
            "metadata" to mapOf(
                "processing_time_ms" to elapsedTime,
                "detected_markers" to detectedMarkers.keys.toList()
            ),
            "images" to mapOf(
                "warped_image_base64" to warpedBase64,
                "annotated_image_base64" to annotatedBase64,
                "info_section_base64" to infoSectionBase64
            )
        )
    }
    
    /**
     * Warp image to template coordinates using homography
     * Uses ALL detected markers (not just 4 corners) for better accuracy
     * Matches backend grade_pipeline.py behavior
     */
    private fun warpToTemplate(
        img: Mat,
        detectedMarkers: Map<Int, Point>,
        templatePositions: Map<Int, Point>,
        template: Map<String, Any>
    ): Pair<Mat, Mat>? {
        val inputPoints = mutableListOf<Point>()
        val templatePoints = mutableListOf<Point>()
        
        // Use ALL detected markers that exist in template (not just corners)
        // This matches backend grade_pipeline.py behavior for better accuracy
        for ((id, detectedPos) in detectedMarkers) {
            val templatePos = templatePositions[id] ?: continue
            inputPoints.add(detectedPos)
            templatePoints.add(templatePos)
        }
        
        // Need at least 4 points for homography
        if (inputPoints.size < 4) {
            return null
        }
        
        val srcMat = MatOfPoint2f()
        srcMat.fromList(inputPoints)
        
        val dstMat = MatOfPoint2f()
        dstMat.fromList(templatePoints)
        
        // Find homography matrix
        val H = Calib3d.findHomography(srcMat, dstMat, Calib3d.RANSAC, 5.0)
        srcMat.release()
        dstMat.release()
        
        if (H.empty()) {
            return null
        }
        
        // Get output size from template
        val infoSection = template["info_section"] as? Map<String, Any>
        // Position is not used directly, but keeping for reference
        @Suppress("UNUSED_VARIABLE")
        val infoPos = if (infoSection != null) getPosition(infoSection["position"]) else null
        
        // Default size if not specified
        val outputWidth = 2481
        val outputHeight = 3508
        
        // Warp perspective
        val warped = Mat()
        Imgproc.warpPerspective(img, warped, H, Size(outputWidth.toDouble(), outputHeight.toDouble()))
        H.release()
        
        // Convert to grayscale
        val warpedGray = Mat()
        Imgproc.cvtColor(warped, warpedGray, Imgproc.COLOR_BGR2GRAY)
        
        return Pair(warped, warpedGray)
    }
    
    /**
     * Read ID section (student, quiz, or class ID)
     */
    @Suppress("UNCHECKED_CAST")
    private fun readIdSection(
        img: Mat,
        gray: Mat,
        section: Map<String, Any>,
        label: String
    ): List<Int> {
        val columns = section["columns"] as? List<Map<String, Any>> ?: return emptyList()
        val minPixels = MIN_ID_PIXELS[label] ?: 600
        
        val digits = mutableListOf<Int>()
        
        for (column in columns) {
            val bubbles = column["bubbles"] as? List<Map<String, Any>> ?: continue
            
            // Find bounding box for this column
            val box = getBoundingBox(bubbles, gray.rows(), gray.cols())
            
            // Threshold the region
            val (thresh, origin) = thresholdRegion(gray, box)
            
            // Find the bubble with most black pixels
            var best: Triple<Int, Int, Map<String, Any>>? = null  // (count, value, bubble)
            
            for (bubble in bubbles) {
                val pos = getBubblePosition(bubble) ?: continue
                val radius = getBubbleRadius(bubble) ?: continue
                val value = (bubble["value"] as? Number)?.toInt() ?: continue
                
                val x = pos.first.toInt() - origin.first
                val y = pos.second.toInt() - origin.second
                
                // Create mask for this bubble
                val mask = Mat.zeros(thresh.size(), CvType.CV_8UC1)
                Imgproc.circle(mask, Point(x.toDouble(), y.toDouble()), radius, Scalar(255.0), -1)
                
                // Count non-zero pixels
                val masked = Mat()
                Core.bitwise_and(thresh, thresh, masked, mask)
                val count = Core.countNonZero(masked)
                
                mask.release()
                masked.release()
                
                if (count >= minPixels && (best == null || count > best.first)) {
                    best = Triple(count, value, bubble)
                }
            }
            
            thresh.release()
            
            if (best != null) {
                digits.add(best.second)
                
                // Draw highlight on selected bubble
                val bubble = best.third
                val pos = getBubblePosition(bubble)
                val radius = getBubbleRadius(bubble)
                if (pos != null && radius != null) {
                    Imgproc.circle(
                        img,
                        Point(pos.first, pos.second),
                        radius,
                        COLOR_CORRECT,
                        2
                    )
                }
            } else {
                // No bubble detected - might be empty, return partial result
                return emptyList()
            }
        }
        
        return digits
    }
    
    /**
     * Detect which bubble is marked in a question
     * Returns: bubble index (0-4) or -1 if none/multiple
     */
    @Suppress("UNCHECKED_CAST")
    private fun detectMarkedBubble(
        gray: Mat,
        bubbles: List<Map<String, Any>>,
        minPixels: Int
    ): Int {
        val box = getBoundingBox(bubbles, gray.rows(), gray.cols())
        val (thresh, origin) = thresholdRegion(gray, box)
        
        val marked = mutableListOf<Pair<Int, Int>>() // (count, index)
        
        for ((index, bubble) in bubbles.withIndex()) {
            val pos = getBubblePosition(bubble) ?: continue
            val radius = getBubbleRadius(bubble) ?: continue
            
            val x = pos.first.toInt() - origin.first
            val y = pos.second.toInt() - origin.second
            
            // Create mask for this bubble
            val mask = Mat.zeros(thresh.size(), CvType.CV_8UC1)
            Imgproc.circle(mask, Point(x.toDouble(), y.toDouble()), radius, Scalar(255.0), -1)
            
            // Count non-zero pixels
            val masked = Mat()
            Core.bitwise_and(thresh, thresh, masked, mask)
            val count = Core.countNonZero(masked)
            
            mask.release()
            masked.release()
            
            if (count >= minPixels) {
                marked.add(Pair(count, index))
            }
        }
        
        thresh.release()
        
        return when {
            marked.isEmpty() -> -1  // No answer (blank)
            marked.size == 1 -> marked[0].second  // Single answer
            else -> marked.maxByOrNull { it.first }?.second ?: -1  // Multiple - take strongest
        }
    }
    
    /**
     * Detect which bubble is marked AND draw circle on annotated image
     * Returns: bubble index (0-4) or -1 if none
     * Draws: Green circle on selected bubble
     */
    @Suppress("UNCHECKED_CAST")
    private fun detectMarkedBubbleAndDraw(
        gray: Mat,
        annotated: Mat,
        bubbles: List<Map<String, Any>>,
        minPixels: Int
    ): Int {
        val box = getBoundingBox(bubbles, gray.rows(), gray.cols())
        val (thresh, origin) = thresholdRegion(gray, box)
        
        val marked = mutableListOf<Triple<Int, Int, Map<String, Any>>>() // (count, index, bubble)
        
        for ((index, bubble) in bubbles.withIndex()) {
            val pos = getBubblePosition(bubble) ?: continue
            val radius = getBubbleRadius(bubble) ?: continue
            
            val x = pos.first.toInt() - origin.first
            val y = pos.second.toInt() - origin.second
            
            // Create mask for this bubble
            val mask = Mat.zeros(thresh.size(), CvType.CV_8UC1)
            Imgproc.circle(mask, Point(x.toDouble(), y.toDouble()), radius, Scalar(255.0), -1)
            
            // Count non-zero pixels
            val masked = Mat()
            Core.bitwise_and(thresh, thresh, masked, mask)
            val count = Core.countNonZero(masked)
            
            mask.release()
            masked.release()
            
            if (count >= minPixels) {
                marked.add(Triple(count, index, bubble))
            }
        }
        
        thresh.release()
        
        // Determine selected answer
        val selectedIndex: Int
        val selectedBubble: Map<String, Any>?
        
        when {
            marked.isEmpty() -> {
                // No answer - blank (don't draw anything for initial scan)
                // Correct answer will be shown after grading with createAnnotatedImage
                selectedIndex = -1
                selectedBubble = null
            }
            marked.size == 1 -> {
                selectedIndex = marked[0].second
                selectedBubble = marked[0].third
            }
            else -> {
                // Multiple - take strongest
                val strongest = marked.maxByOrNull { it.first }
                selectedIndex = strongest?.second ?: -1
                selectedBubble = strongest?.third
            }
        }
        
        // Draw green circle on selected bubble (for initial scan preview)
        if (selectedBubble != null) {
            val pos = getBubblePosition(selectedBubble)
            val radius = getBubbleRadius(selectedBubble)
            if (pos != null && radius != null) {
                Imgproc.circle(
                    annotated,
                    Point(pos.first, pos.second),
                    radius,
                    COLOR_CORRECT, // Green - selected answer
                    3
                )
            }
        }
        
        return selectedIndex
    }
    
    /**
     * Detect marked bubble AND check if multiple bubbles are marked
     * Returns: Pair(selectedIndex, isMultiple)
     * - selectedIndex: 0-4 for selected bubble, -1 for blank
     * - isMultiple: true if more than one bubble is marked
     */
    @Suppress("UNCHECKED_CAST")
    private fun detectMarkedBubbleAndDrawWithMultiple(
        gray: Mat,
        annotated: Mat,
        bubbles: List<Map<String, Any>>,
        minPixels: Int
    ): Pair<Int, Boolean> {
        val box = getBoundingBox(bubbles, gray.rows(), gray.cols())
        val (thresh, origin) = thresholdRegion(gray, box)
        
        val marked = mutableListOf<Triple<Int, Int, Map<String, Any>>>() // (count, index, bubble)
        
        for ((index, bubble) in bubbles.withIndex()) {
            val pos = getBubblePosition(bubble) ?: continue
            val radius = getBubbleRadius(bubble) ?: continue
            
            val x = pos.first.toInt() - origin.first
            val y = pos.second.toInt() - origin.second
            
            // Create mask for this bubble
            val mask = Mat.zeros(thresh.size(), CvType.CV_8UC1)
            Imgproc.circle(mask, Point(x.toDouble(), y.toDouble()), radius, Scalar(255.0), -1)
            
            // Count non-zero pixels
            val masked = Mat()
            Core.bitwise_and(thresh, thresh, masked, mask)
            val count = Core.countNonZero(masked)
            
            mask.release()
            masked.release()
            
            if (count >= minPixels) {
                marked.add(Triple(count, index, bubble))
            }
        }
        
        thresh.release()
        
        // Check if multiple bubbles are marked
        val isMultiple = marked.size > 1
        
        // Determine selected answer
        val selectedIndex: Int
        val selectedBubble: Map<String, Any>?
        
        when {
            marked.isEmpty() -> {
                selectedIndex = -1
                selectedBubble = null
            }
            marked.size == 1 -> {
                selectedIndex = marked[0].second
                selectedBubble = marked[0].third
            }
            else -> {
                // Multiple - take strongest for now
                val strongest = marked.maxByOrNull { it.first }
                selectedIndex = strongest?.second ?: -1
                selectedBubble = strongest?.third
            }
        }
        
        // Draw on annotated image
        if (selectedBubble != null) {
            val pos = getBubblePosition(selectedBubble)
            val radius = getBubbleRadius(selectedBubble)
            if (pos != null && radius != null) {
                // Use different color for multiple marks
                val color = if (isMultiple) COLOR_WRONG else COLOR_CORRECT
                Imgproc.circle(
                    annotated,
                    Point(pos.first, pos.second),
                    radius,
                    color,
                    3
                )
            }
        }
        
        return Pair(selectedIndex, isMultiple)
    }
    
    /**
     * Get bounding box for a list of bubbles
     */
    @Suppress("UNCHECKED_CAST")
    private fun getBoundingBox(
        bubbles: List<Map<String, Any>>,
        imgHeight: Int,
        imgWidth: Int
    ): IntArray {
        var minX = Int.MAX_VALUE
        var minY = Int.MAX_VALUE
        var maxX = 0
        var maxY = 0
        var maxRadius = 0
        
        for (bubble in bubbles) {
            val pos = getBubblePosition(bubble) ?: continue
            val radius = getBubbleRadius(bubble) ?: 0
            
            val x = pos.first.toInt()
            val y = pos.second.toInt()
            
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
            maxRadius = max(maxRadius, radius)
        }
        
        // Add padding for radius
        val x1 = max(minX - maxRadius, 0)
        val y1 = max(minY - maxRadius, 0)
        val x2 = min(maxX + maxRadius, imgWidth)
        val y2 = min(maxY + maxRadius, imgHeight)
        
        return intArrayOf(x1, y1, x2, y2)
    }
    
    /**
     * Threshold a region of the image
     */
    private fun thresholdRegion(gray: Mat, box: IntArray): Pair<Mat, Pair<Int, Int>> {
        val (x1, y1, x2, y2) = box.toList()
        
        // Extract ROI
        val roi = gray.submat(y1, y2, x1, x2)
        
        // Apply Otsu thresholding
        val thresh = Mat()
        Imgproc.threshold(roi, thresh, 0.0, 255.0, Imgproc.THRESH_BINARY_INV or Imgproc.THRESH_OTSU)
        
        roi.release()
        
        return Pair(thresh, Pair(x1, y1))
    }
    
    /**
     * Crop info section (the fillable form area with name, student ID bubbles) from image
     * Uses info_section position from template
     */
    private fun cropInfoSection(img: Mat, template: Map<String, Any>): String? {
        try {
            // Get info_section from template (the fillable form area)
            val infoSection = template["info_section"] as? Map<String, Any>
            if (infoSection == null) {
                android.util.Log.w(TAG, "info_section not found in template")
                return null
            }
            
            val position = infoSection["position"] as? List<*>
            if (position == null || position.size < 4) {
                android.util.Log.w(TAG, "info_section position invalid")
                return null
            }
            
            val x = (position[0] as? Number)?.toInt() ?: return null
            val y = (position[1] as? Number)?.toInt() ?: return null
            val w = (position[2] as? Number)?.toInt() ?: return null
            val h = (position[3] as? Number)?.toInt() ?: return null
            
            // Add small padding
            val padding = 10
            val cropX = maxOf(0, x - padding)
            val cropY = maxOf(0, y - padding)
            val cropW = minOf(img.cols() - cropX, w + padding * 2)
            val cropH = minOf(img.rows() - cropY, h + padding * 2)
            
            // Crop the region
            val roi = Rect(cropX, cropY, cropW, cropH)
            val cropped = Mat(img, roi)
            
            // Encode to base64
            val result = encodeImageToBase64(cropped)
            cropped.release()
            
            android.util.Log.d(TAG, "cropInfoSection success: ${cropW}x${cropH}")
            return result
        } catch (e: Exception) {
            android.util.Log.e(TAG, "cropInfoSection failed: ${e.message}")
            return null
        }
    }
    
    /**
     * Encode image to base64 string
     */
    private fun encodeImageToBase64(img: Mat): String? {
        return try {
            // Convert to bitmap
            val bitmap = Bitmap.createBitmap(img.cols(), img.rows(), Bitmap.Config.ARGB_8888)
            
            // Convert BGR to RGBA for Android
            val rgba = Mat()
            Imgproc.cvtColor(img, rgba, Imgproc.COLOR_BGR2RGBA)
            Utils.matToBitmap(rgba, bitmap)
            rgba.release()
            
            // Compress to JPEG with lower quality for large images
            val outputStream = ByteArrayOutputStream()
            val quality = if (img.cols() > 2000 || img.rows() > 2000) 70 else 85
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream)
            bitmap.recycle()
            
            // Encode to base64
            Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to encode image: ${e.message}")
            null
        } catch (oom: OutOfMemoryError) {
            android.util.Log.e(TAG, "Out of memory encoding image")
            // Try with smaller size
            try {
                val resized = Mat()
                val scale = 0.5
                Imgproc.resize(img, resized, Size(img.cols() * scale, img.rows() * scale))
                val result = encodeImageToBase64(resized)
                resized.release()
                result
            } catch (e: Exception) {
                null
            }
        }
    }
    
    /**
     * Decode base64 string to Mat image
     */
    private fun decodeBase64ToMat(base64String: String): Mat? {
        return try {
            val imageBytes = Base64.decode(base64String, Base64.DEFAULT)
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            if (bitmap == null) {
                return null
            }
            
            val mat = Mat()
            Utils.bitmapToMat(bitmap, mat)
            bitmap.recycle()
            
            // Convert RGBA to BGR
            val bgrMat = Mat()
            Imgproc.cvtColor(mat, bgrMat, Imgproc.COLOR_RGBA2BGR)
            mat.release()
            
            bgrMat
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to decode base64 image: ${e.message}")
            null
        }
    }
    
    /**
     * Create annotated image with grading results (ZipGrade style)
     * Colors: 
     * - Green = correct answer selected
     * - Red = wrong answer selected  
     * - Yellow = show correct answer (when wrong or blank)
     */
    @Suppress("UNCHECKED_CAST")
    private fun createAnnotatedImage(
        warpedImageBase64: String,
        template: Map<String, Any>,
        studentAnswers: Map<String, Any>,
        correctAnswers: Map<String, Any>
    ): String? {
        // Decode warped image
        val img = decodeBase64ToMat(warpedImageBase64) ?: return null
        
        try {
            val answerArea = template["answer_area"] as? Map<String, Any>
            val questions = answerArea?.get("questions") as? List<Map<String, Any>> ?: emptyList()
            
            for (question in questions) {
                val qNum = (question["question"] as? Number)?.toInt() ?: continue
                val bubbles = question["bubbles"] as? List<Map<String, Any>> ?: continue
                val qKey = qNum.toString() // 1-based key
                
                // Get student answer and correct answer (both are 0-based indices)
                val studentAns = when (val ans = studentAnswers[qKey]) {
                    is Number -> ans.toInt()
                    is List<*> -> (ans.firstOrNull() as? Number)?.toInt() ?: -1
                    else -> -1
                }
                val correctAns = when (val ans = correctAnswers[qKey]) {
                    is Number -> ans.toInt()
                    else -> -1
                }
                
                // Draw based on correctness (ZipGrade style - 3 colors only)
                when {
                    studentAns == -1 -> {
                        // Blank - draw yellow on correct answer to show what should be selected
                        if (correctAns >= 0 && correctAns < bubbles.size) {
                            val bubble = bubbles[correctAns]
                            drawBubbleCircle(img, bubble, COLOR_SHOW_CORRECT, 3) // Yellow
                        }
                    }
                    studentAns == correctAns -> {
                        // Correct - draw green on student answer
                        if (studentAns >= 0 && studentAns < bubbles.size) {
                            val bubble = bubbles[studentAns]
                            drawBubbleCircle(img, bubble, COLOR_CORRECT, 3) // Green
                        }
                    }
                    else -> {
                        // Wrong - draw red on student answer, yellow on correct answer
                        if (studentAns >= 0 && studentAns < bubbles.size) {
                            val bubble = bubbles[studentAns]
                            drawBubbleCircle(img, bubble, COLOR_WRONG, 3) // Red
                        }
                        if (correctAns >= 0 && correctAns < bubbles.size) {
                            val bubble = bubbles[correctAns]
                            drawBubbleCircle(img, bubble, COLOR_SHOW_CORRECT, 3) // Yellow - show correct
                        }
                    }
                }
            }
            
            // Encode and return
            return encodeImageToBase64(img)
        } finally {
            img.release()
        }
    }
    
    /**
     * Draw circle on a bubble
     */
    private fun drawBubbleCircle(img: Mat, bubble: Map<String, Any>, color: Scalar, thickness: Int) {
        val pos = getBubblePosition(bubble) ?: return
        val radius = getBubbleRadius(bubble) ?: return
        
        Imgproc.circle(
            img,
            Point(pos.first, pos.second),
            radius,
            color,
            thickness
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

