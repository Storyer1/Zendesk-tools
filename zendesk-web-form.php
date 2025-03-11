<?php
// Replace with your actual Zendesk subdomain
$subdomain = "Your-Zendesk-domain";
$apiUrl = "https://{$subdomain}.zendesk.com/api/v2/requests.json";

$message = '';
$messageClass = '';

// Process form submission
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Validate inputs
    $email = filter_input(INPUT_POST, 'email', FILTER_VALIDATE_EMAIL);
    $subject = trim($_POST['subject'] ?? '');
    $body = trim($_POST['body'] ?? '');
    
    $errors = [];
    
    if (!$email) {
        $errors[] = "Please enter a valid email address.";
    }
    
    if (empty($subject)) {
        $errors[] = "Subject is required.";
    }
    
    if (empty($body)) {
        $errors[] = "Feedback message is required.";
    }
    
    // If no errors, submit to Zendesk
    if (empty($errors)) {
        // Construct the JSON payload
        $payload = [
            "request" => [
                "requester" => [
                    "name" => "Customer",
                    "email" => $email
                ],
                "subject" => $subject,
                "comment" => [
                    "body" => $body
                ]
            ]
        ];
        
        // Initialize cURL session
        $ch = curl_init($apiUrl);
        
        // Set cURL options
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Accept: application/json'
        ]);
        
        // Execute the request
        $response = curl_exec($ch);
        
        // Check for errors
        if (curl_errno($ch)) {
            $message = "Error: " . curl_error($ch);
            $messageClass = "error";
        } else {
            // Decode the JSON response
            $responseData = json_decode($response, true);
            
            // Check if the request was successful
            if (isset($responseData['request']['id'])) {
                $message = "Thank you for your feedback! Your ticket ID is: " . $responseData['request']['id'];
                $messageClass = "success";
                // Reset form fields
                $email = $subject = $body = '';
            } else {
                $message = "Error submitting feedback: " . ($responseData['error'] ?? $response);
                $messageClass = "error";
            }
        }
        
        // Close cURL session
        curl_close($ch);
    } else {
        $message = implode("<br>", $errors);
        $messageClass = "error";
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Feedback Form</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h2 {
            color: #333;
            margin-top: 0;
        }
        .form-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        input[type="email"],
        input[type="text"],
        textarea {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        textarea {
            height: 150px;
            resize: vertical;
        }
        button {
            background-color: #4CAF50;
            color: white;
            padding: 10px 15px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #45a049;
        }
        .message {
            padding: 10px;
            margin-bottom: 15px;
            border-radius: 4px;
        }
        .success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Send Feedback</h2>
        
        <?php if (!empty($message)): ?>
            <div class="message <?php echo $messageClass; ?>">
                <?php echo $message; ?>
            </div>
        <?php endif; ?>
        
        <form method="post" action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]); ?>">
            <div class="form-group">
                <label for="email">Email:</label>
                <input type="email" id="email" name="email" value="<?php echo htmlspecialchars($email ?? ''); ?>" required>
            </div>
            
            <div class="form-group">
                <label for="subject">Subject:</label>
                <input type="text" id="subject" name="subject" value="<?php echo htmlspecialchars($subject ?? ''); ?>" required>
            </div>
            
            <div class="form-group">
                <label for="body">Your Feedback:</label>
                <textarea id="body" name="body" required><?php echo htmlspecialchars($body ?? ''); ?></textarea>
            </div>
            
            <button type="submit">Submit Feedback</button>
        </form>
    </div>
</body>
</html>