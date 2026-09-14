<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$host = 'localhost';
$db   = 'u278523899_queuego';
$user = 'u278523899_Queuego123';
$pass = 'Queuego123';
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
} catch (\PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed: ' . $e->getMessage()]);
    exit();
}

$action = $_GET['action'] ?? '';

function jsonResponse($data, $status = 200) {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit();
}

switch ($action) {
    case 'get_counters':
        $stmt = $pdo->query("SELECT * FROM counters");
        jsonResponse(['success' => true, 'data' => $stmt->fetchAll()]);
        break;

    case 'get_queues':
        $date = $_GET['date'] ?? date('Y-m-d');
        $stmt = $pdo->prepare("SELECT * FROM queues WHERE DATE(created_at) = ? ORDER BY id DESC");
        $stmt->execute([$date]);
        jsonResponse(['success' => true, 'data' => $stmt->fetchAll()]);
        break;

    case 'take_queue':
        $input = json_decode(file_get_contents('php://input'), true);
        $counterId = $input['counter_id'] ?? 1;
        $customerName = $input['customer_name'] ?? 'Tamu';
        
        $stmt = $pdo->prepare("SELECT name FROM counters WHERE id = ?");
        $stmt->execute([$counterId]);
        $counter = $stmt->fetch();
        $prefix = strpos(strtolower($counter['name'] ?? ''), 'teller') !== false ? 'A' : 'B';
        
        $today = date('Y-m-d');
        $stmt = $pdo->prepare("SELECT queue_number FROM queues WHERE counter_id = ? AND DATE(created_at) = ? ORDER BY id DESC LIMIT 1");
        $stmt->execute([$counterId, $today]);
        $last = $stmt->fetch();
        
        $nextNum = 1;
        if ($last && isset($last['queue_number'])) {
            $numPart = intval(substr($last['queue_number'], 1));
            $nextNum = $numPart + 1;
        }
        $queueNumber = sprintf("%s%03d", $prefix, $nextNum);

        $stmt = $pdo->prepare("INSERT INTO queues (counter_id, queue_number, customer_name, status, created_at) VALUES (?, ?, ?, 'waiting', NOW())");
        $stmt->execute([$counterId, $queueNumber, $customerName]);
        $newId = $pdo->lastInsertId();

        $stmt = $pdo->prepare("SELECT * FROM queues WHERE id = ?");
        $stmt->execute([$newId]);
        jsonResponse(['success' => true, 'data' => $stmt->fetch()]);
        break;

    case 'update_status':
        $input = json_decode(file_get_contents('php://input'), true);
        $id = $input['id'] ?? 0;
        $status = $input['status'] ?? '';
        
        $allowed = ['waiting', 'calling', 'serving', 'completed', 'cancelled', 'skipped'];
        if (!in_array($status, $allowed)) {
            jsonResponse(['success' => false, 'message' => 'Invalid status'], 400);
        }

        $extra = "";
        if ($status === 'calling' || $status === 'serving') {
            $extra = ", called_at = NOW()";
        } else if ($status === 'completed' || $status === 'cancelled' || $status === 'skipped') {
            $extra = ", completed_at = NOW()";
        }

        $stmt = $pdo->prepare("UPDATE queues SET status = ? $extra WHERE id = ?");
        $stmt->execute([$status, $id]);

        $stmt = $pdo->prepare("SELECT * FROM queues WHERE id = ?");
        $stmt->execute([$id]);
        jsonResponse(['success' => true, 'data' => $stmt->fetch()]);
        break;

    default:
        jsonResponse(['success' => false, 'message' => 'Invalid action or endpoint'], 404);
}
?>

