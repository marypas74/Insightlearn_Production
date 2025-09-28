using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using InsightLearn.Core.Interfaces;
using MailKit.Net.Smtp;
using MimeKit;
using MailKit.Security;

namespace InsightLearn.Infrastructure.Services;

public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendEmailVerificationAsync(string email, string firstName, string token)
    {
        var subject = "Verify Your Email Address - InsightLearn.Cloud";
        var verificationUrl = $"{_configuration["AppSettings:FrontendUrl"]}/verify-email?token={token}";

        var body = $@"
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-align: center; padding: 30px 20px; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .button {{ display: inline-block; background: #007bff; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 30px; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>Welcome to InsightLearn.Cloud!</h1>
        </div>
        <div class='content'>
            <h2>Hi {firstName},</h2>
            <p>Thank you for registering with InsightLearn.Cloud! To complete your registration and start your learning journey, please verify your email address by clicking the button below:</p>

            <div style='text-align: center;'>
                <a href='{verificationUrl}' class='button'>Verify Email Address</a>
            </div>

            <p>If the button doesn't work, you can also copy and paste this link into your browser:</p>
            <p style='background: #e9ecef; padding: 10px; border-radius: 5px; word-break: break-all;'>{verificationUrl}</p>

            <p><strong>This verification link will expire in 24 hours.</strong></p>

            <p>If you didn't create an account with InsightLearn.Cloud, please ignore this email.</p>

            <p>Best regards,<br>The InsightLearn.Cloud Team</p>
        </div>
        <div class='footer'>
            <p>© 2024 InsightLearn.Cloud. All rights reserved.</p>
        </div>
    </div>
</body>
</html>";

        await SendEmailAsync(email, subject, body);
        _logger.LogInformation("Email verification sent to {Email}", email);
    }

    public async Task SendPasswordResetAsync(string email, string firstName, string token)
    {
        var subject = "Reset Your Password - InsightLearn.Cloud";
        var resetUrl = $"{_configuration["AppSettings:FrontendUrl"]}/reset-password?token={token}";

        var body = $@"
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #dc3545 0%, #fd7e14 100%); color: white; text-align: center; padding: 30px 20px; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .button {{ display: inline-block; background: #dc3545; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 30px; font-size: 12px; color: #666; }}
        .warning {{ background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 15px; border-radius: 5px; margin: 20px 0; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>Password Reset Request</h1>
        </div>
        <div class='content'>
            <h2>Hi {firstName},</h2>
            <p>We received a request to reset your password for your InsightLearn.Cloud account. If you made this request, click the button below to reset your password:</p>

            <div style='text-align: center;'>
                <a href='{resetUrl}' class='button'>Reset Password</a>
            </div>

            <p>If the button doesn't work, you can also copy and paste this link into your browser:</p>
            <p style='background: #e9ecef; padding: 10px; border-radius: 5px; word-break: break-all;'>{resetUrl}</p>

            <div class='warning'>
                <strong>Important Security Information:</strong>
                <ul>
                    <li>This password reset link will expire in 1 hour</li>
                    <li>If you didn't request this password reset, please ignore this email</li>
                    <li>For security reasons, change your password immediately if you suspect unauthorized access</li>
                </ul>
            </div>

            <p>Best regards,<br>The InsightLearn.Cloud Security Team</p>
        </div>
        <div class='footer'>
            <p>© 2024 InsightLearn.Cloud. All rights reserved.</p>
        </div>
    </div>
</body>
</html>";

        await SendEmailAsync(email, subject, body);
        _logger.LogInformation("Password reset email sent to {Email}", email);
    }

    public async Task SendWelcomeEmailAsync(string email, string firstName)
    {
        var subject = "Welcome to InsightLearn.Cloud - Let's Start Learning!";
        var dashboardUrl = $"{_configuration["AppSettings:FrontendUrl"]}/dashboard";

        var body = $@"
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; text-align: center; padding: 30px 20px; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .button {{ display: inline-block; background: #28a745; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 30px; font-size: 12px; color: #666; }}
        .feature {{ background: white; padding: 20px; border-radius: 5px; margin: 15px 0; border-left: 4px solid #28a745; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>Welcome to InsightLearn.Cloud!</h1>
            <p>Your learning journey starts now</p>
        </div>
        <div class='content'>
            <h2>Hi {firstName},</h2>
            <p>Congratulations! Your email has been verified and your InsightLearn.Cloud account is now active. We're excited to have you join our learning community!</p>

            <div style='text-align: center;'>
                <a href='{dashboardUrl}' class='button'>Go to Dashboard</a>
            </div>

            <h3>What's Next?</h3>

            <div class='feature'>
                <h4>🎯 Explore Courses</h4>
                <p>Browse our extensive library of courses taught by industry experts.</p>
            </div>

            <div class='feature'>
                <h4>📚 Track Your Progress</h4>
                <p>Monitor your learning journey with detailed progress tracking and achievements.</p>
            </div>

            <div class='feature'>
                <h4>💬 Join the Community</h4>
                <p>Connect with fellow learners and instructors in our discussion forums.</p>
            </div>

            <div class='feature'>
                <h4>📱 Learn Anywhere</h4>
                <p>Access your courses on any device, anytime, anywhere.</p>
            </div>

            <p>If you have any questions or need help getting started, feel free to contact our support team.</p>

            <p>Happy learning!<br>The InsightLearn.Cloud Team</p>
        </div>
        <div class='footer'>
            <p>© 2024 InsightLearn.Cloud. All rights reserved.</p>
        </div>
    </div>
</body>
</html>";

        await SendEmailAsync(email, subject, body);
        _logger.LogInformation("Welcome email sent to {Email}", email);
    }

    public async Task SendLoginNotificationAsync(string email, string firstName, string ipAddress, DateTime loginTime)
    {
        var subject = "New Login to Your InsightLearn.Cloud Account";

        var body = $@"
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #6f42c1 0%, #e83e8c 100%); color: white; text-align: center; padding: 30px 20px; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .info-box {{ background: #e7f3ff; border: 1px solid #b8daff; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 30px; font-size: 12px; color: #666; }}
        .warning {{ background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 15px; border-radius: 5px; margin: 20px 0; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>Login Notification</h1>
        </div>
        <div class='content'>
            <h2>Hi {firstName},</h2>
            <p>We wanted to let you know that there was a new login to your InsightLearn.Cloud account.</p>

            <div class='info-box'>
                <h4>Login Details:</h4>
                <p><strong>Date & Time:</strong> {loginTime:F} UTC</p>
                <p><strong>IP Address:</strong> {ipAddress}</p>
                <p><strong>Location:</strong> Approximate location based on IP</p>
            </div>

            <div class='warning'>
                <h4>Was this you?</h4>
                <p>If you recognize this login, no action is needed. If you don't recognize this activity, please:</p>
                <ul>
                    <li>Change your password immediately</li>
                    <li>Review your account for any unauthorized changes</li>
                    <li>Contact our support team if you need assistance</li>
                </ul>
            </div>

            <p>We continuously monitor your account for suspicious activity to keep it secure.</p>

            <p>Best regards,<br>The InsightLearn.Cloud Security Team</p>
        </div>
        <div class='footer'>
            <p>© 2024 InsightLearn.Cloud. All rights reserved.</p>
        </div>
    </div>
</body>
</html>";

        await SendEmailAsync(email, subject, body);
        _logger.LogInformation("Login notification sent to {Email} for IP {IpAddress}", email, ipAddress);
    }

    private async Task SendEmailAsync(string to, string subject, string body)
    {
        try
        {
            var emailSettings = _configuration.GetSection("EmailSettings");

            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(
                emailSettings["SenderName"] ?? "InsightLearn.Cloud",
                emailSettings["SenderEmail"] ?? throw new InvalidOperationException("Sender email not configured")
            ));
            message.To.Add(new MailboxAddress("", to));
            message.Subject = subject;

            var bodyBuilder = new BodyBuilder
            {
                HtmlBody = body
            };
            message.Body = bodyBuilder.ToMessageBody();

            using var client = new SmtpClient();

            // Connect to SMTP server
            var host = emailSettings["SmtpHost"] ?? throw new InvalidOperationException("SMTP host not configured");
            var port = int.Parse(emailSettings["SmtpPort"] ?? "587");
            var useSsl = bool.Parse(emailSettings["UseSsl"] ?? "true");

            await client.ConnectAsync(host, port, useSsl ? SecureSocketOptions.StartTls : SecureSocketOptions.None);

            // Authenticate
            var username = emailSettings["Username"] ?? throw new InvalidOperationException("SMTP username not configured");
            var password = emailSettings["Password"] ?? throw new InvalidOperationException("SMTP password not configured");
            await client.AuthenticateAsync(username, password);

            // Send email
            await client.SendAsync(message);
            await client.DisconnectAsync(true);

            _logger.LogInformation("Email sent successfully to {Email} with subject '{Subject}'", to, subject);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send email to {Email} with subject '{Subject}'", to, subject);
            throw new InvalidOperationException($"Failed to send email to {to}", ex);
        }
    }
}