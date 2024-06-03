ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root';

CREATE TABLE IF NOT EXISTS rate_limits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(255) NOT NULL,
    rate_limit INT NOT NULL,
    rate_timestamps JSON
);

INSERT INTO rate_limits (token, rate_limit, rate_timestamps) VALUES
    ('default_token', 5, '[]');
