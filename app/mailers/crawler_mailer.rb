class CrawlerMailer < ApplicationMailer
  def failure_report(failures)
    @failures = failures
    @ran_at = Time.current

    mail(
      to:      Rails.application.credentials.dig(:mailer, :error_recipient),
      subject: "[Cinephilia] #{failures.size} crawler(s) failed on #{@ran_at.strftime('%d.%m.%Y')}"
    )
  end
end
