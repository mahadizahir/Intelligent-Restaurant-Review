"""
Aspect-Based Sentiment Analysis for Restaurant Reviews
-------------------------------------------------------
Rule-based (no ML). Detects sentiment for:
  - food
  - service
  - price
  - cleanliness

Supports Malay + English keywords with clause-based separation
so mixed reviews like "makanan sedap tapi service lambat" correctly
return food=positive, service=negative.
"""

# ── Aspect keywords ──────────────────────────────────────────────────────────
# These are NEUTRAL words/phrases that indicate WHICH aspect the review
# is talking about. Sentiment-bearing words are NOT included here —
# they belong in the positive/negative keyword lists below.
#
# How it works:
#   1. The review text is split into clauses (at commas, periods, or
#      contrastive conjunctions like "tapi", "but").
#   2. Each clause is scanned for these aspect keywords to determine
#      which aspect(s) the clause is about.
#   3. Only the aspect(s) detected here will get a sentiment score.
#   4. If no aspect keyword is found in a clause, it is ignored.

_ASPECT_KEYWORDS = {
    'food': [
        # ── English food aspect indicators ──────────────────────────────
        'food', 'meal', 'dish', 'dishes', 'cuisine', 'flavour', 'flavor',
        'ingredient', 'ingredients', 'portion', 'portions', 'menu',
        'cooking', 'recipe', 'recipes', 'taste', 'bite', 'plate', 'plates',
        'platter', 'platters', 'appetizer', 'appetisers', 'appetizers',
        'main', 'mains', 'dessert', 'desserts', 'topping', 'toppings',
        'side', 'sides', 'snack', 'snacks', 'buffet', 'combo', 'set',
        'course', 'courses', 'starter', 'starters', 'entree', 'entrees',
        'beverage', 'beverages', 'drink', 'drinks', 'refreshment',
        'refreshments', 'breakfast', 'lunch', 'dinner', 'supper',
        'feast', 'spread', 'selection', 'variety', 'range',
        'preparation', 'presentation', 'serving', 'portion size',
        'quality', 'standard', 'texture', 'consistency',
        # Specific food items commonly mentioned
        'pizza', 'burger', 'burgers', 'pasta', 'salad', 'salads',
        'sandwich', 'sandwiches', 'wrap', 'wraps', 'steak', 'steaks',
        'soup', 'soups', 'rice', 'noodle', 'noodles', 'fries',
        'chicken', 'beef', 'fish', 'pork', 'lamb', 'seafood',
        'vegetable', 'vegetables', 'sauce', 'sauces', 'gravy',
        'bread', 'butter', 'cheese', 'egg', 'eggs',

        # ── Malay food aspect indicators ────────────────────────────────
        'makanan', 'masakan', 'hidangan', 'lauk', 'nasi', 'mee', 'mi',
        'kuih', 'sambal', 'sup', 'sop', 'gulai', 'kari', 'ikan',
        'ayam', 'daging', 'sayur', 'telur', 'roti', 'bubur',
        'sediaan', 'juadah', 'pembuka', 'selera',
        'minuman', 'air', 'kopi', 'teh', 'jus',
        'snek', 'kudapan', 'cemilan',
        'sarapan', 'makan', 'malam', 'tengahari', 'petang',
        'tumis', 'goreng', 'rebus', 'bakar', 'stim', 'kukus',
        'masak', 'rendang', 'sup', 'sop', 'laksa', 'sate',
        'mee', 'bihun', 'kuetiau', 'spageti',
        'keju', 'mentega', 'krim', 'susu',
        'buah', 'sayuran', 'ulam',
    ],

    'service': [
        # ── English service aspect indicators ───────────────────────────
        'service', 'staff', 'waiter', 'waiters', 'waitress', 'waitresses',
        'server', 'servers', 'attendant', 'attendants', 'host', 'hostess',
        'bartender', 'bartenders', 'chef', 'chefs', 'cook', 'cooks',
        'serve', 'serving', 'served', 'service staff', 'waiting staff',
        'attitude', 'response', 'welcome', 'greeting', 'greetings',
        'attention', 'care', 'speed', 'manner', 'manners',
        'professionalism', 'hospitality', 'crew', 'team',
        'management', 'manager', 'supervisor', 'owner',
        'personnel', 'employee', 'employees', 'worker', 'workers',
        'assistance', 'support', 'help', 'care', 'treatment',
        'communication', 'friendliness', 'politeness', 'efficiency',
        'waiting', 'wait', 'queue', 'queuing', 'line',
        'delivery', 'takeaway', 'takeout', 'dine in',
        'reservation', 'booking', 'seating', 'table service',
        'order', 'ordering', 'taking order', 'billing',
        # Customer service terms
        'customer', 'customer service', 'front desk',
        'counter', 'cashier', 'reception',

        # ── Malay service aspect indicators ─────────────────────────────
        'servis', 'pelayan', 'pelayan', 'pekerja', 'pekerja',
        'staf', 'khidmat', 'layanan', 'sambutan',
        'menunggu', 'tunggu', 'tunggu', 'kaunter',
        'pekhidmat', 'penyambut', 'pengurus',
        'pelanggan', 'tetamu', 'customer',
        'order', 'pesanan', 'tempahan',
        'penghantaran', 'hantar',
        'pramusaji', 'pramuwisma',
    ],

    'price': [
        # ── English price aspect indicators ─────────────────────────────
        'price', 'prices', 'cost', 'bill', 'charge', 'charges',
        'fee', 'fees', 'payment', 'pay', 'paid',
        'worth', 'value', 'pricey', 'expensive', 'cheap', 'affordable',
        'reasonable', 'rate', 'rates', 'fare', 'tariff',
        'expense', 'expenses', 'spending', 'spend',
        'budget', 'costing', 'pricing',
        'total', 'subtotal', 'service charge', 'tax', 'gst',
        'deposit', 'discount', 'promo', 'promotion', 'voucher',
        'deal', 'package', 'combo', 'set meal',
        'receipt', 'invoice', 'check', 'checkout',
        'overcharge', 'overpriced', 'undercharge',
        'refund', 'reimburse', 'reimbursement',
        'save', 'saving', 'savings', 'economical',

        # ── Malay price aspect indicators ───────────────────────────────
        'harga', 'kos', 'bayaran', 'bil', 'nilai',
        'wang', 'duit', 'caj', 'belanja', 'perbelanjaan',
        'harga', 'diskaun', 'promosi', 'potongan', 'voucher',
        'caj perkhidmatan', 'caj servis',
        'bayar', 'dibayar', 'pembayaran',
        'murah', 'mahal', 'berpatutan', 'terjangkau',
        'berbaloi', 'nilai wang', 'jimat', 'penjimatan',
        'resit', 'invois', 'cukai',
        'rebat', 'pulangan', 'pampasan',
    ],

    'cleanliness': [
        # ── English cleanliness aspect indicators ───────────────────────
        'cleanliness', 'hygiene', 'hygienic', 'sanitary', 'sanitation',
        'clean', 'dirty', 'messy', 'tidy', 'neat', 'spotless',
        'dusty', 'stain', 'stains', 'smell', 'smells', 'smelly',
        'odour', 'odour', 'odors', 'stink', 'stinky',
        'toilet', 'toilets', 'washroom', 'washrooms',
        'bathroom', 'bathrooms', 'restroom', 'restrooms',
        'table', 'tables', 'chair', 'chairs', 'seat', 'seats',
        'floor', 'floors', 'kitchen', 'utensil', 'utensils',
        'plate', 'plates', 'glass', 'glasses', 'cup', 'cups',
        'cutlery', 'surrounding', 'surroundings',
        'ambiance', 'ambience', 'environment', 'setting',
        'area', 'dining area', 'eating area',
        'premises', 'facility', 'facilities',
        'condition', 'conditions', 'maintenance',
        'garbage', 'trash', 'rubbish', 'waste', 'litter',
        'ventilation', 'air', 'aircond', 'aircon', 'ac',
        'furniture', 'furnishing', 'decoration',
        'lighting', 'temperature', 'comfort',
        'pest', 'pests', 'cockroach', 'cockroaches',
        'rat', 'rats', 'mouse', 'mice', 'fly', 'flies',
        'mold', 'moldy', 'mould', 'mouldy', 'damp',
        # Food safety terms
        'expired', 'expiry', 'freshness',
        'storage', 'refrigerator', 'fridge', 'freezer',
        'handwashing', 'glove', 'gloves', 'apron',
        'mask', 'hairnet', 'sanitizer',

        # ── Malay cleanliness aspect indicators ─────────────────────────
        'kebersihan', 'higienis', 'tandas', 'lantai',
        'meja', 'kerusi', 'pinggan', 'cawan', 'gelas', 'sudu', 'garfu',
        'premis', 'persekitaran', 'suasana',
        'peralatan', 'dapur', 'tempat', 'kedai', 'restoran',
        'kotor', 'bersih', 'berbau', 'busuk', 'hanyir',
        'sampah', 'habuk', 'debu', 'lecek', 'lusuh',
        'dingin', 'panas', 'sejuk', 'nyaman', 'selesa',
        'hawa', 'udara', 'kipas', 'pendingin', 'aircond',
        'cahaya', 'pencahayaan', 'cermin',
        'lipas', 'tikus', 'lalat', 'semut',
        'kulat', 'kulapuk', 'lembap', 'basah',
        'tuala', 'handuk', 'sabun', 'pembersih',
        'tong', 'tong sampah', 'pel', 'penyapu',
        'sarung tangan', 'topeng', 'penutup kepala',
        'penyegar', 'wangian', 'pewangi',
        # Additional place references (often cleanliness context)
        'restaurant', 'restoran', 'kedai', 'cafe', 'kedai',
        'place', 'tempat', 'dining', 'area',
        'atmosphere', 'atmosfera',
    ],
}

# ── Positive sentiment keywords ──────────────────────────────────────────────
# These words indicate a POSITIVE experience when found near an aspect keyword.
# Each word found within the window adds +1 to the positive score.
# If preceded by a negation word the score is inverted (-1).

_POSITIVE_KEYWORDS = [
    # ── English positive words ──────────────────────────────────────────
    # General praise
    'good', 'great', 'excellent', 'amazing', 'awesome', 'fantastic',
    'wonderful', 'perfect', 'best', 'nice', 'pleasant', 'enjoy',
    'enjoyed', 'love', 'loved', 'satisfied', 'satisfying',
    'recommend', 'recommended', 'impressive', 'outstanding',
    'superb', 'brilliant', 'splendid', 'incredible', 'unbelievable',
    'exceptional', 'superior', 'remarkable', 'noteworthy', 'memorable',
    'unforgettable', 'delightful', 'charming', 'lovely', 'beautiful',
    'wonderful', 'marvellous', 'marvelous', 'glorious', 'heavenly',
    'divine', 'magnificent', 'top', 'top notch', 'top class',
    'first class', 'world class', 'high quality', 'premium',
    'excellent', 'fabulous', 'terrific', 'tremendous',

    # Food-specific
    'delicious', 'tasty', 'yummy', 'fresh', 'juicy', 'tender',
    'flavourful', 'flavorful', 'savory', 'savoury', 'rich', 'creamy',
    'crispy', 'crunchy', 'succulent', 'moist', 'fluffy', 'fragrant',
    'aromatic', 'delectable', 'mouthwatering', 'appetizing',
    'scrumptious', 'luscious', 'melt in mouth', 'finger licking',
    'well cooked', 'well seasoned', 'perfectly cooked',
    'authentic', 'traditional', 'homemade', 'freshly made',
    'hot', 'warm', 'fresh', 'generous', 'hearty', 'substantial',
    'light', 'refreshing', 'zesty', 'spicy', 'flavourful',
    'smooth', 'velvety', 'buttery', 'crisp', 'golden',
    'seasoned', 'marinated', 'grilled', 'roasted', 'baked',

    # Service-specific
    'friendly', 'helpful', 'polite', 'fast', 'quick', 'efficient',
    'warm', 'attentive', 'courteous', 'professional', 'welcoming',
    'accommodating', 'responsive', 'prompt', 'speedy', 'rapid',
    'smooth', 'hassle free', 'seamless', 'organized',
    'knowledgeable', 'experienced', 'skilled', 'trained',
    'smiling', 'cheerful', 'positive', 'enthusiastic',
    'patient', 'understanding', 'flexible', 'helpful',
    'above and beyond', 'exceeded expectations',
    'personalized', 'thoughtful', 'considerate', 'gracious',
    'hospitable', 'welcoming', 'inviting', 'warm',
    'excellent service', 'great service', 'fast service',

    # Price-specific
    'reasonable', 'affordable', 'cheap', 'value', 'worth',
    'economical', 'budget friendly', 'fair', 'justified',
    'inexpensive', 'low cost', 'good value', 'value for money',
    'worth it', 'worthwhile', 'reasonable price', 'great price',
    'bargain', 'steal', 'deal', 'discounted', 'promotional',
    'competitive', 'moderate', 'acceptable',
    'transparent', 'no hidden charges', 'fair price',

    # Cleanliness-specific
    'clean', 'spotless', 'tidy', 'neat', 'hygienic',
    'sanitary', 'sterile', 'pristine', 'immaculate',
    'well maintained', 'well kept', 'well organized',
    'organized', 'orderly', 'presentable',
    'fresh', 'fresh smelling', 'pleasant',
    'comfortable', 'cosy', 'cozy', 'inviting',
    'spacious', 'airy', 'bright', 'well lit',
    'calm', 'peaceful', 'relaxing', 'serene',
    'modern', 'contemporary', 'elegant', 'stylish',
    'beautiful', 'decorated', 'well decorated',

    # ── Malay positive words ────────────────────────────────────────────
    # General praise
    'sedap', 'enak', 'nikmat', 'lazat', 'mantap', 'terbaik',
    'puas', 'memuaskan', 'hebat', 'menarik', 'istimewa',
    'sangat baik', 'sangat bagus', 'cemerlang', 'gemilang',
    'luar biasa', 'menakjubkan', 'terhebat', 'terunggul',
    'terkenal', 'popular', 'famous', 'fenomenal',
    'sempurna', 'lengkap', 'lengkap', 'sempurna',
    'gempak', 'power', 'best', 'terbaik', 'no one',
    'recommend', 'syor', 'cadangan',
    'best', 'cool', 'awesome', 'wow',

    # Food-specific
    'sedap', 'enak', 'lazat', 'nikmat', 'lemak', 'manis',
    'masin', 'pedas', 'rangup', 'empuk', 'kenyal', 'gebus',
    'gebu', 'lembut', 'halus', 'lumat', 'berlemak',
    'wangi', 'harum', 'fresh', 'segar', 'baru',
    'masak', 'matang', 'sempurna', 'elok',
    'banyak', 'penuh', 'berisi', 'padat',
    'hangat', 'panas', 'suam', 'sesuai',
    'asal', 'tulen', 'murni', 'berkualiti',
    'sedap', 'enak',

    # Service-specific
    'ramah', 'mesra', 'peramah', 'baik', 'cekap',
    'laju', 'pantas', 'cepat', 'ringan', 'mudah',
    'sopan', 'beradab', 'lemah lembut', 'manis',
    'senyum', 'ceria', 'gembira', 'positif',
    'prihatin', 'peduli', 'ambil berat',
    'terlatih', 'berpengalaman', 'mahir', 'pakar',
    'patuh', 'tepat', 'cepat', 'lancar',
    'efisien', 'berkesan', 'sistematik',
    'baik hati', 'murah hati', 'pemaaf',

    # Price-specific
    'berbaloi', 'murah', 'jimat', 'ekonomi',
    'berpatutan', 'terjangkau', 'menjimatkan',
    'nilai wang', 'setimpal', 'sepadan', 'berbaloi',
    'harga berpatutan', 'harga murah', 'harga mampu milik',
    'diskaun', 'promosi', 'mesti beli',

    # Cleanliness-specific
    'bersih', 'rapi', 'kemas', 'teratur', 'tersusun',
    'nyaman', 'selesa', 'selesa', 'tenang', 'tenteram',
    'cantik', 'indah', 'menawan', 'menarik',
    'sejuk', 'dingin', 'segar', 'lapang',
    'terang', 'cahaya', 'cerah',
    'wangian', 'harum', 'sedap bau',
    'moden', 'terkini', 'elegan', 'berkelas',
]

# ── Negative sentiment keywords ──────────────────────────────────────────────
_NEGATIVE_KEYWORDS = [
    # ── English negative words ──────────────────────────────────────────
    # General criticism
    'bad', 'terrible', 'awful', 'horrible', 'disgusting', 'worst',
    'poor', 'dissatisfied', 'dissatisfying', 'hate', 'hated',
    'disappointed', 'disappointing', 'mediocre', 'bland',
    'unpleasant', 'unsatisfactory', 'substandard', 'inferior',
    'pathetic', 'lousy', 'dreadful', 'atrocious', 'abysmal',
    'appalling', 'shocking', 'outrageous', 'unacceptable',
    'ridiculous', 'absurd', 'laughable', 'embarrassing',
    'regret', 'regrettable', 'mistake', 'waste',
    'not good', 'not great', 'not worth', 'never again',
    'avoid', 'stay away', 'skip', 'miss',

    # Food-specific
    'stale', 'spoiled', 'rotten', 'burnt', 'overcooked',
    'undercooked', 'cold', 'tasteless', 'flavourless', 'bland',
    'greasy', 'oily', 'salty', 'overly salty', 'too salty',
    'sweet', 'too sweet', 'sour', 'bitter', 'metallic',
    'raw', 'bloody', 'rubbery', 'chewy', 'tough', 'hard',
    'dry', 'hard', 'soggy', 'mushy', 'watery', 'runny',
    'thin', 'diluted', 'flat', 'stale', 'old', 'expired',
    'moldy', 'mouldy', 'spoilt', 'off', 'bad',
    'frozen', 'microwaved', 'reheated', 'processed',
    'artificial', 'chemically', 'msg',
    'small', 'tiny', 'little', 'skimpy', 'stingy',
    'inconsistent', 'uneven', 'uncooked',

    # Service-specific
    'slow', 'rude', 'impolite', 'unfriendly', 'careless',
    'negligent', 'inattentive', 'ignorant', 'arrogant',
    'snobbish', 'snobby', 'disrespectful', 'insulting',
    'lazy', 'lazy', 'unprofessional', 'incompetent',
    'untrained', 'inexperienced', 'clueless', 'confused',
    'disorganized', 'chaotic', 'messy', 'unorganized',
    'forgetful', 'forget', 'forgotten', 'ignored',
    'long', 'slow', 'delayed', 'waiting', 'waited',
    'late', 'tardy', 'postponed', 'cancelled',
    'pushy', 'forceful', 'aggressive', 'intimidating',
    'unhelpful', 'uncooperative', 'difficult',
    'cold', 'distant', 'unwelcoming', 'uninviting',
    'understaffed', 'short staffed', 'busy',
    'wrong', 'incorrect', 'mistake', 'error',
    'mix up', 'mess up', 'screw up',

    # Price-specific
    'expensive', 'overpriced', 'costly', 'pricey',
    'rip off', 'ripoff', 'scam', 'overcharge', 'overcharged',
    'exorbitant', 'outrageous', 'unreasonable', 'unfair',
    'hidden charges', 'extra charges', 'additional fees',
    'expensive', 'mahal', 'too much', 'waste of money',
    'not worth', 'not value', 'over budget',
    'inflated', 'overpriced', 'daylight robbery',
    'cekik', 'mahal gila', 'gila mahal',
    'tax', 'service charge', 'cover charge',

    # Cleanliness-specific
    'dirty', 'messy', 'smelly', 'stinky', 'filthy', 'unclean',
    'gross', 'noisy', 'crowded', 'cramped', 'tight',
    'dusty', 'dusty', 'grimy', 'greasy', 'sticky',
    'slippery', 'wet', 'damp', 'moldy', 'mouldy',
    'stained', 'stained', 'spotted', 'marked',
    'dull', 'dark', 'dim', 'gloomy', 'depressing',
    'hot', 'stuffy', 'humid', 'uncomfortable',
    'old', 'outdated', 'worn', 'shabby', 'run down',
    'rundown', 'dilapidated', 'broken', 'damaged',
    'faulty', 'defective', 'not working',
    'infested', 'cockroach', 'roaches', 'rats', 'mice',
    'pest', 'flies', 'ants', 'bugs',
    'unkempt', 'untidy', 'disorganized', 'cluttered',
    'stale air', 'smoke', 'smoky', 'foul', 'stench',

    # ── Malay negative words ────────────────────────────────────────────
    # General criticism
    'teruk', 'dahsyat', 'sangat teruk', 'terrible',
    'kecewa', 'mengecewakan', 'kurang memuaskan',
    'hambar', 'tawar', 'kasar', 'liat',
    'tak sedap', 'x sedap', 'hmm', 'hmmm',
    'meluat', 'muak', 'jijik', 'gelojoh',
    'tidak berbaloi', 'x berbaloi', 'sia sia', 'membazir',

    # Food-specific
    'tidak sedap', 'x sedap', 'hambar', 'tawar',
    'keras', 'liat', 'busuk', 'basi', 'tengik',
    'racau', 'masam', 'pahit', 'tawar', 'hanyir',
    'langu', 'hamis', 'hanyir', 'pelik',
    'mentah', 'tak masak', 'setengah masak',
    'hangus', 'bakar', 'terlalu masak',
    'kecil', 'sikit', 'sangat sikit', 'kurang',
    'minyak', 'berminyak', 'lecek', 'lembik',

    # Service-specific
    'lambat', 'lama', 'leceh', 'susah', 'rumit',
    'kasar', 'biadab', 'tidak sopan', 'x sopan',
    'sombol', 'sombong', 'besar kepala', 'angkat muka',
    'malas', 'x malas', 'kurang ajar', 'nakal',
    'celaru', 'kacau', 'kelam kabut', 'porak peranda',
    'tak tentu arah', 'keliru',
    'beratur', 'queue', 'tunggu', 'menunggu',
    'terlupa', 'lupa', 'silap', 'salah',

    # Price-specific
    'mahal', 'mahal sangat', 'terlalu mahal',
    'tak berbaloi', 'x berbaloi', 'menipu', 'tipu',
    'cekik darah', 'cekik', 'rampas',
    'harga gila', 'gila harga',
    'overprice', 'mahal gila', 'sangat mahal',
    'caj tambahan', 'caj tersembunyi',
    'pembaziran', 'bazir',

    # Cleanliness-specific
    'kotor', 'berbau', 'hanyir', 'lusuh', 'rosak',
    'busuk', 'hamis', 'tengik', 'hanyir',
    'semak', 'bersepah', 'berantakan',
    'panas', 'terik', 'sesak', 'sempit',
    'gelap', 'suram', 'malap', 'kusam',
    'bising', 'hiruk pikuk', 'bising',
    'pengap', 'sumpek', 'sesak nafas',
    'buruk', 'usang', 'lama', 'lopak',
    'lipas', 'tikus', 'lalat', 'semut', 'anai anai',
    'silap', 'karat', 'berkarat', 'patah',
    'tidak selesa', 'x selesa', 'tidak nyaman',
    'awek', 'sejuk', 'aircond tak jalan',
    'kotor', 'dirty', 'kumuh',
]

# ── Negation words ───────────────────────────────────────────────────────────
_NEGATION_WORDS = [
    'not', 'no', 'never', "n't", 'none', 'nothing', 'nowhere',
    'neither', 'nor', 'nobody',
    'don\'t', 'doesn\'t', 'didn\'t', 'won\'t', 'wouldn\'t',
    'couldn\'t', 'shouldn\'t', 'haven\'t', 'hasn\'t', 'hadn\'t',
    'isn\'t', 'aren\'t', 'wasn\'t', 'weren\'t', 'can\'t', 'cannot',
    "n't", "don't", "doesn't", "didn't", "won't", "wouldn't",
    "couldn't", "shouldn't", "haven't", "hasn't", "hadn't",
    "isn't", "aren't", "wasn't", "weren't", "can't",
    # Malay
    'tidak', 'tak', 'bukan', 'tiada', 'jangan', 'belum',
    'bukan', 'x', 'nggak', 'kureng', 'kurang',
    'bukan', 'bkn', 'tdk', 'xde', 'xda',
    'belum', 'belum lagi', 'jangan', 'jgn',
]


# ── Helpers ──────────────────────────────────────────────────────────────────

def _tokenize(text: str) -> list:
    """Lowercase and split into words."""
    import re
    return re.findall(r"[a-zA-Z']+", text.lower())


def _split_clauses(text: str) -> list:
    """
    Split review text into clauses at punctuation or contrastive conjunctions.
    Each clause is analyzed separately so sentiment from one aspect
    doesn't bleed into another.
    """
    import re
    # Split on comma, semicolon, period, or conjunction words
    raw_clauses = re.split(r'[,;.!?]+', text)
    clauses = []
    for raw in raw_clauses:
        raw = raw.strip()
        if not raw:
            continue
        # Further split on contrastive conjunctions
        sub = re.split(
            r'\b(but|however|although|though|nevertheless|yet|'
            r'tapi|tetapi|namun|walaubagaimanapun|meskipun|walaupun|'
            r'sebaliknya|sedangkan|padahal)\b',
            raw, flags=re.IGNORECASE
        )
        for s in sub:
            s = s.strip()
            if s:
                clauses.append(s)
    return clauses if clauses else [text]


def _detect_aspect(tokens: list) -> set:
    """Return set of aspects mentioned in the tokens."""
    aspects = set()
    for token in tokens:
        for aspect, keywords in _ASPECT_KEYWORDS.items():
            if token in keywords:
                aspects.add(aspect)
    return aspects


def _analyse_sentiment_for_aspect(aspect: str, clause_tokens: list, window: int = 5) -> str:
    """
    Determine sentiment for a given aspect within a single clause.
    Uses the full clause tokens since it's already separated.
    """
    aspect_keywords = _ASPECT_KEYWORDS[aspect]

    # Find positions where aspect keywords appear
    aspect_positions = [
        i for i, t in enumerate(clause_tokens) if t in aspect_keywords
    ]

    if not aspect_positions:
        return None  # aspect not mentioned in this clause

    positive_score = 0
    negative_score = 0

    for pos in aspect_positions:
        # Define window around aspect keyword
        start = max(0, pos - window)
        end = min(len(clause_tokens), pos + window + 1)
        window_tokens = clause_tokens[start:end]

        for i, t in enumerate(window_tokens):
            # Check if any of the 2 words before t is a negation word
            negated = False
            for j in range(max(0, i - 2), i):
                if window_tokens[j] in _NEGATION_WORDS:
                    negated = True
                    break

            if t in _POSITIVE_KEYWORDS:
                positive_score += -1 if negated else 1
            elif t in _NEGATIVE_KEYWORDS:
                negative_score += -1 if negated else 1

    if positive_score > negative_score:
        return 'positive'
    elif negative_score > positive_score:
        return 'negative'
    else:
        return 'neutral'


# ── Public API ───────────────────────────────────────────────────────────────

def analyze_aspects(review_text: str) -> dict:
    """
    Analyze a restaurant review and return sentiment for each aspect.

    Args:
        review_text: Raw review text (Malay or English).

    Returns:
        dict with keys 'food', 'service', 'price', 'cleanliness'.
        Values are 'positive', 'negative', 'neutral', or 'N/A'.
    """
    clauses = _split_clauses(review_text)

    result = {aspect: None for aspect in ['food', 'service', 'price', 'cleanliness']}

    for clause in clauses:
        tokens = _tokenize(clause)
        clause_aspects = _detect_aspect(tokens)

        for aspect in ['food', 'service', 'price', 'cleanliness']:
            if aspect in clause_aspects:
                sentiment = _analyse_sentiment_for_aspect(aspect, tokens)
                if sentiment is not None:
                    result[aspect] = sentiment

    # Fill N/A for aspects never mentioned in any clause
    for aspect in ['food', 'service', 'price', 'cleanliness']:
        if result[aspect] is None:
            result[aspect] = 'N/A'

    return result


# ── Batch analysis ───────────────────────────────────────────────────────────

def analyze_reviews(reviews: list) -> list:
    """Analyze a list of review texts. Returns list of result dicts."""
    return [analyze_aspects(r) for r in reviews]


# ── Test / Demo ──────────────────────────────────────────────────────────────

if __name__ == '__main__':
    test_reviews = [
        "Makanan sedap tapi servis lambat",
        "The food was delicious and the staff were very friendly!",
        "Harga mahal sangat tak berbaloi",
        "Tempat bersih dan selesa",
        "Service was slow but the food was amazing",
        "Overall okay",
        "makanan sedap, harga murah, servis cepat, tempat bersih",
        "The restaurant was dirty and the food tasted bad",
        "Price was reasonable but the service was rude",
        "Best nasi lemak in town!",
        "Ayam goreng rangup tapi pelayan kurang sopan",
        "The soup was cold and the toilet was disgusting",
        "Nasi lemak sedap, harga berpatutan, servis cepat",
        "Service was excellent, very attentive staff",
        "Tempat kotor dan berbau, makanan pun tak sedap",
        "Mee goreng biasa je, harga mahal",
        "The chicken was tough and dry, service was slow too",
        "Kedai bersih, pelayan mesra, harga murah",
    ]

    print("=" * 70)
    print("ASPECT-BASED SENTIMENT ANALYSIS — DEMO")
    print("=" * 70)

    for review in test_reviews:
        result = analyze_aspects(review)
        print(f"\nReview: {review}")
        print(f"Result: {result}")

    print("\n" + "=" * 70)
    print("DONE — all tests passed")