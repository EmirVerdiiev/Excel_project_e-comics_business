SELECT CONCAT('SELECT * FROM ', table_name, ';')
FROM information_schema.tables
WHERE table_schema = 'comic_platform_practice';

SELECT * FROM campaigns;
SELECT * FROM coin_packages;
SELECT * FROM comics;
SELECT * FROM episode_unlocks;
SELECT * FROM episodes;
SELECT * FROM favorites;
SELECT * FROM payments;
SELECT * FROM reading_sessions;
SELECT * FROM refunds;
SELECT * FROM users;

-- Виведи 20 останніх зареєстрованих користувачів: 
-- user_id, registered_at, country_code, device_type. 
-- При однаковій даті сортуй за user_id за спаданням.

Select user_id, registered_at, country_code, device_type
From users
Order by registered_at DESC, user_id DESC
Limit 20
;

Select user_id, registered_at, country_code, device_type
From users
Order by registered_at DESC
Limit 20
;

-- Знайди користувачів зі США, 
-- які зареєструвалися в березні з mobile.
-- Використай напіввідкритий інтервал дат [2026-03-01, 2026-04-01).
Select user_id, registered_at, country_code, device_type
From users
Where 
	country_code = 'US' 
    and device_type = 'mobile' 
    and registered_at between "2026-03-01" and "2026-03-31"
;

-- Виведи 10 найбільших успішних оплат. 
-- Покажи фактичну суму, а не каталожну ціну пакета. 
-- Виріши, як упорядкувати однакові суми.

Select *
From payments
Where completed_at is not NULL
Order by amount_usd DESC
Limit 10
;

-- Знайди органічних користувачів (campaign_id IS NULL) та окремо незавершені оплати (pending).
Select *
From users
Where campaign_id is NULL
;

Select *
From payments
Where status = 'pending'
Limit 10 -- the datasets are big
;

-- JOIN: INNER / LEFT / RIGHT / FULL

-- 5.Для кожної оплати виведи payment_id, 
-- країну користувача, назву пакета, 
-- amount_usd і status.
Select 
	payment_id, 
	u.country_code as users_country,
	cp.package_name,
    amount_usd, 
    status
From payments p
Left Join users u on p.user_id = u.user_id
Left Join coin_packages cp on p.package_id = cp.package_id
;

Select *
from payments
Limit 5
;

-- Для КОЖНОГО користувача порахуй кількість успішних оплат, 
-- включно з нулем. Як умова на status у WHERE може змінити зміст LEFT JOIN?
Select u.user_id, Count(p.payment_id)
From users u
Left join payments p 
	on u.user_id = p.user_id 
    and p.status = 'succeeded'
Group by u.user_id
;				
-- Виведи всі кампанії та кількість залучених користувачів.
-- Кампанія без реєстрацій має залишитися.
-- Зроби версії з LEFT JOIN та RIGHT JOIN.

Select c.campaign_id,c.campaign_name, Count(u.user_id) as users_count
From campaigns c
Left join users u on c.campaign_id = u.campaign_id
Group by c.campaign_id
Limit 10
;

-- Знайди комікси без жодного читання. 
-- Врахуй, що читання пов’язане з коміксом через епізод.
Select *
From comics c 
Left Join episodes e on c.comic_id = e.comic_id
Limit 10
;

Select *
From episodes
Limit 10
;

Select *
From reading_sessions
Limit 10
;

WITH episode_reads AS(
	Select 
		e.episode_id,e.comic_id, Count(r.episode_id) as reads_count
	From episodes e
	Left Join reading_sessions r on e.episode_id = r.episode_id
	Group by e.episode_id, e.comic_id
)
Select c.comic_id,c.title, SUM(er.reads_count) as reads_count
From comics c
LEFT JOIN episode_reads er
	on c.comic_id = er.comic_id
Group by c.comic_id, c.title
Having coalesce(SUM(er.reads_count),0) = 0
;
-- завдання 9
-- Створи дві вибірки user_id: 
-- хоча б один успішний платіж у травні 
-- та хоча б одне читання у травні. 
-- Отримай усіх, хто входить хоча б в одну, 
-- з двома індикаторами.
-- Відтвори FULL OUTER JOIN через 
-- LEFT JOIN + UNION ALL + unmatched right rows, 
-- бо прямого FULL JOIN у MySQL немає.
-- Спочатку усунь повтори всередині кожної вибірки.

WITH may_payers AS (
    SELECT DISTINCT user_id
    FROM payments
    WHERE status = 'succeeded'
      AND completed_at >= '2026-05-01'
      AND completed_at < '2026-06-01'
),
may_readers AS (
    SELECT DISTINCT user_id
    FROM reading_sessions
    WHERE started_at >= '2026-05-01'
      AND started_at < '2026-06-01'
)

-- Усі платники: перевіряємо, чи вони також читали
SELECT
    p.user_id,
    1 AS paid_in_may,
    CASE
        WHEN r.user_id IS NOT NULL THEN 1
        ELSE 0
    END AS read_in_may
FROM may_payers p
LEFT JOIN may_readers r
    ON p.user_id = r.user_id

UNION ALL

-- Додаємо читачів, які не платили
SELECT
    r.user_id,
    0 AS paid_in_may,
    1 AS read_in_may
FROM may_readers r
LEFT JOIN may_payers p
    ON r.user_id = p.user_id
WHERE p.user_id IS NULL

ORDER BY user_id;


-- GROUP BY / SUM / COUNT / AVG / HAVING
-- Порахуй реєстрації за країною та
--  частку країни серед усіх реєстрацій.
Select 
	country_code, 
	Count(user_id) as user_count,
    Round((Count(user_id) * 100 / SUM(Count(user_id)) over ()),2) as percentage 
From users
Group by country_code
;

Select 
	country_code, 
	Count(user_id) as user_count,
    Round(Count(user_id) * 100 / (Select COUNT(*) from users) ,2) as percentage 
From users
Group by country_code
;

-- 11) Порахуй успішні оплати: 
-- кількість, загальну суму та середню суму платежу
 -- за календарними місяцями completed_at.
 
 WITH succeeded_payments AS(
	 Select *
	 From payments
	 Where status = 'succeeded'
 )
 Select 
	Count(*) as payments_count, 
	SUM(amount_usd) as total_amount,
    Round(AVG(amount_usd),2)  as avg_payment,
	YEAR(completed_at) as year, 
    Month(completed_at) as month
From succeeded_payments
Group by year, month
Order by year ASC, month ASC
;
# або коротше:
Select 
	Count(*) as payments_count, 
	SUM(amount_usd) as total_amount,
    Round(AVG(amount_usd),2)  as avg_payment,
	YEAR(completed_at) as year, 
    Month(completed_at) as month
From payments
Where status="succeeded"
Group by year, month 
Order by year ASC, month ASC
;


-- Побудуй топ-5 коміксів за унікальними читачами. 
-- Окремо покажи кількість сеансів і поясни різницю.
 select * 
 From comics
 Limit 5
 ;
 
 select * 
 From reading_sessions
 Limit 5
 ;
 
  
Select session_id, user_id, episode_id, started_at, 
From reading_sessions r
Left join episodes e on r.episode_id = e.episode_id
 ;
 
 
WITH comics_reading_session AS(
	Select c.comic_id, c.title, e.episode_id, r.session_id,r.started_at, r.user_id
	From comics c
	Left Join episodes e on c.comic_id = e.comic_id
	Left Join reading_sessions r on e.episode_id = r.episode_id
)
Select 
	comic_id, 
	title,
	Count(distinct user_id) as unique_readers,
    Count(session_id) as sessions_count
From comics_reading_session
Group by comic_id, title
Order by unique_readers DESC
Limit 5
;


-- Знайди користувачів з принаймні двома успішними оплатами.
 WITH succeeded_payments AS(
	 Select *
	 From payments
	 Where status = 'succeeded'
 )
 Select 
	u.user_id, 
    Count(sc.payment_id) as payments_count,
    Sum(amount_usd) as total_amount
 From users u 
 Left join succeeded_payments sc on u.user_id = sc.user_id
 Group by u.user_id
 Having payments_count >=2
 Order by total_amount DESC
;
# коротше
 Select 
	u.user_id, 
    Count(p.payment_id) as payments_count,
    Sum(p.amount_usd) as total_amount
 From users u 
 Left join payments p 
	on u.user_id = p.user_id
	and status = 'succeeded'
 Group by u.user_id
 Having payments_count >=2
 Order by total_amount DESC
;

--
-- Task 14 — частка читачів, які дочитали епізод
-- Для кожного епізоду, який хоча б раз читали, виведи:
-- episode_id
-- кількість унікальних читачів — unique_readers
-- кількість читачів, які хоча б раз досягли progress_percent = 100, — completed_readers
-- частку таких читачів у відсотках — completion_rate, округлену до 2 знаків

With unique_readers As(
	Select 
		episode_id, 
		Count(distinct user_id) as unique_user_count
	From reading_sessions
	Group by episode_id
),
completed_reads As(
	Select episode_id, Count(distinct user_id) as completed_reads
    From reading_sessions
    Where progress_percent = 100
    Group by episode_id
),
episode_stat AS(
	Select 
		u.episode_id,
		unique_user_count,
		COALESCE(c.completed_reads,0) as completed_reads,
		ROUND(
			COALESCE(c.completed_reads, 0) * 100.0
			/ u.unique_user_count,
			2
		) AS completion_rate
	From unique_readers u
	Left Join completed_reads c on u.episode_id = c.episode_id
	Order by completion_rate ASC
)
Select Count(*) as count_less_than_50
From episode_stat
Where completed_reads<=50
;

-- Task 15 — платежі, більші за середній
-- Знайди всі успішні платежі, 
-- сума яких більша за середню суму успішного платежу за весь період.

Select *,  (Select Avg(amount_usd) from payments where status = 'succeeded') as avg_salary
from payments
Where status = 'succeeded' and amount_usd > (Select Avg(amount_usd) from payments where status = 'succeeded')
;

-- Task 16 — читають, але не платять
-- Знайди користувачів, які:
-- мають хоча б один сеанс читання;
-- ніколи не мали успішної оплати (status = 'succeeded').

WITH succeeded_payments_by_user AS(
	Select u.user_id, Count(Case p.status when "succeeded" then 1 else Null end) as succeeded_payments_count
    From users u
    Left Join payments p on u.user_id = p.user_id
    Group by u.user_id
    Having succeeded_payments_count = 0
),
 reading_users AS( -- at least one time
	Select u.user_id, Count(session_id) as sessions_count
    From users u
    Left Join reading_sessions r on u.user_id = r.user_id
    Group by u.user_id
    Having sessions_count >= 0
)
Select s.user_id,s.succeeded_payments_count,r.sessions_count
From succeeded_payments_by_user s
Join reading_users r on s.user_id = r.user_id
;



WITH succeeded_payments_by_user AS(
	Select u.user_id, count(payment_id) as unsucceeded_payments_count
    From users u
    Left Join payments p on u.user_id = p.user_id
    Group by u.user_id
    Having Count(Case When p.status = 'succeeded' then 1 END) = 0
),
 reading_users AS( -- at least one time
	Select u.user_id, Count(session_id) as sessions_count
    From users u
    Left Join reading_sessions r on u.user_id = r.user_id
    Group by u.user_id
    Having sessions_count >= 0
)
Select s.user_id,s.unsucceeded_payments_count,r.sessions_count
From succeeded_payments_by_user s
Join reading_users r on s.user_id = r.user_id
;

-- ask 17 — комікси з кількістю читачів вище середньої
-- Для кожного коміксу порахуй унікальних читачів, а потім залиш лише комікси, 
-- у яких ця кількість більша за середню кількість унікальних читачів на комікс.

-- Select 
-- 	c.comic_id, 
--     c.title, 
--     Count(Distinct r.user_id) as readers_count,
--     (Sum(Count(Distinct r.user_id)) OVER()) / (Count(c.comic_id) OVER ()) as avg_number_of_readers
-- From comics c
-- Left join episodes e on c.comic_id = e.comic_id
-- Left join reading_sessions r on e.episode_id = r.episode_id
-- Group by c.comic_id
-- ;


WITH readers_by_comic As (
	Select 
		c.comic_id, 
	   c.title, 
		Count(Distinct r.user_id) as readers_count
	From comics c
	Left join episodes e on c.comic_id = e.comic_id
	Left join reading_sessions r on e.episode_id = r.episode_id
	Group by c.comic_id
)
Select comic_id, title, readers_count
From readers_by_comic
Where readers_count > (Select Avg(readers_count) From readers_by_comic)

;


-- Task 18

Select * 
From users
Limit 5
;

-- successful payments
With sessions_count_by_user As(
	Select u.user_id, Count(r.session_id) as read_sessions_count
    From users u
    Left join reading_sessions r on u.user_id = r.user_id
    Group by u.user_id
),
successful_payments As(
	Select 
		u.user_id,
		Count(Case p.status when "succeeded" then 1 else null end) as succeeded_pays_count,
        Sum(CASE when p.status = "succeeded" then p.amount_usd else 0 end) as total_payments
	From users u
	Left Join payments p on u.user_id = p.user_id
	Group by u.user_id
),
Refund_sums_by_user As(
	Select 
		u.user_id,
		Sum(r.amount_usd) as refund_sum
	From users u
	Left Join payments p on u.user_id = p.user_id
	Left Join refunds r on p.payment_id = r.payment_id
	Group by u.user_id
)
Select
	s.user_id,
    s.succeeded_pays_count,
    s.total_payments as paid_usd,
    COALESCE(r.refund_sum,0) as refunded_usd,
    COALESCE(s.total_payments,0)-COALESCE(r.refund_sum,0) as net_cash_usd,
    read_sessions_count
From successful_payments s
Join Refund_sums_by_user r on s.user_id = r.user_id
Join sessions_count_by_user sc on s.user_id = sc.user_id
Order by s.succeeded_pays_count DESC
;


-- Завдання 19 — чисті грошові надходження за місяцями
-- Для кожного місяця, у якому були успішні оплати або повернення, виведи:
-- year, month;
-- paid_usd — суму успішних оплат;
-- refunded_usd — суму повернень;
-- net_cash_usd — різницю між ними.



With revenue_by_month as(
	Select 
		Year(completed_at) as year, 
		Month(completed_at) as month,
		Sum(amount_usd) as paid_usd
	From payments 
    Where status='succeeded'
	Group by Year(completed_at), Month(completed_at)
),
refund_by_month as(
	Select 
		Year(refunded_at) as year, 
		Month(refunded_at) as month,
		Sum(amount_usd) as refunded_usd
	From refunds 
	Group by Year(refunded_at), Month(refunded_at)
)
Select 
	rev.year,
    rev.month,
    rev.paid_usd,
	COALESCE(ref.refunded_usd, 0) AS refunded_usd,
    rev.paid_usd - COALESCE(ref.refunded_usd, 0) AS net_cash_usd
From revenue_by_month rev
Left Join refund_by_month ref on rev.year = ref.year and rev.month = ref.month

-- Додаємо місяці, у яких були лише повернення
UNION ALL
Select ref.year,
    ref.month,
    0 as paid_usd,
    ref.refunded_usd,
    -ref.refunded_usd AS net_cash_usd
From refund_by_month ref
Left Join revenue_by_month rev
	on ref.year = rev.year 
	and ref.month = rev.month
WHERE rev.year IS NULL
ORDER BY year, month;

--   ----

With revenue_by_month as(
	Select 
		Year(completed_at) as year, 
		Month(completed_at) as month,
		Sum(amount_usd) as paid_usd
	From payments 
    Where status='succeeded'
	Group by Year(completed_at), Month(completed_at)
),
refund_by_month as(
	Select 
		Year(refunded_at) as year, 
		Month(refunded_at) as month,
		Sum(amount_usd) as refunded_usd
	From refunds 
	Group by Year(refunded_at), Month(refunded_at)
)
Select *
From revenue_by_month rev
Left Join refund_by_month ref on rev.year = ref.year and rev.month = ref.month

-- Завдання 20 — ефективність рекламних кампаній
-- Для кожної кампанії виведи:
-- - campaign_id, campaign_name;
-- - users_count — кількість залучених користувачів;
-- - payers_count — кількість користувачів із хоча б однією успішною оплатою;
-- - payer_conversion — payers_count / users_count × 100;
-- - acquisition_cost_per_payer — spend_usd / payers_count
;

-- campaigns and their users
WITH campaign_users AS(
	Select
		c.campaign_id,
        c.campaign_name,
		u.user_id,
        c.spend_usd
	From campaigns c
	Left Join users u on c.campaign_id = u.campaign_id
	
),
users_payments_count AS(
	Select u.user_id,Count(p.payment_id) as successfull_payments_count
	From users u
	Left Join payments p on u.user_id = p.user_id and status='succeeded'
	Group by u.user_id
)
Select 
	c.campaign_id,
    c.campaign_name,
    Round(Avg(c.spend_usd),2) as spend_usd,
    Count(c.user_id) as users_count,
    Count(CASE when p.successfull_payments_count > 0 then 1 else Null end) as payers_count,
    Count(CASE when p.successfull_payments_count > 0 then 1 else Null end)*100 / NULLIF(Count(c.user_id),0) as payer_conversion,
    ROUND(AVG(c.spend_usd), 2)
    / NULLIF( COUNT(CASE WHEN p.successfull_payments_count > 0 THEN 1 ELSE NULL END),0) AS acquisition_cost_per_payer
From campaign_users c
Left Join users_payments_count p on c.user_id = p.user_id
Group by c.campaign_id, c.campaign_name
;

-- WITH natural_users AS(
-- 	Select *
-- 	From users
-- 	Where campaign_id is Null
-- ),
-- natural_campaign as(
-- 	Select 9 as campaign_id,
--     "natural" as campaign_name,
--     0 as spend_usd
-- ),
-- successful_payers as (
-- 	Select  
-- 		u.user_id
-- 	From natural_users u
-- 	Left Join payments p on u.user_id = p.user_id
-- 	Group by u.user_id
-- )


-- campaign_id = '100'
-- campaign_name = 'Natural'
-- spend_usd 0 as spend_usd
-- users_count  Count(*)
-- payers_count Should work out the left join
-- payer_conversion (payers_count / users_count) * 100 
-- cquisition_cost_per_payer — spend_usd / payers_count.


-- Завдання 23 — перша успішна оплата кожного користувача
-- Починаємо віконні функції з ROW_NUMBER().
-- Знайди перший успішний платіж кожного платника та виведи:
-- - user_id;
-- - payment_id;
-- - completed_at;
-- - amount_usd.
;

WITH users_succeeded_payments as(
	Select 
		u.user_id, 
        Row_number() OVER(
			Partition by u.user_id
            Order by p.completed_at, p.payment_id
		) as payment_number,
		p.payment_id,
		p.completed_at,
		p.amount_usd
	from users u 
	Left Join payments p on u.user_id = p.user_id and p.status='succeeded'
    Order by u.user_id
)
Select user_id,Coalesce(payment_id,0), Coalesce(completed_at,0),Coalesce(amount_usd,0)
From users_succeeded_payments
Where payment_number = 1

;


WITH numbered_payments AS (
    SELECT
        user_id,
        payment_id,
        completed_at,
        amount_usd,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY completed_at, payment_id
        ) AS payment_number
    FROM payments
    WHERE status = 'succeeded'
)
SELECT
    user_id,
    payment_id,
    completed_at,
    amount_usd
FROM numbered_payments
WHERE payment_number = 1
ORDER BY user_id;
;

# Заняття 24 - рейтинг коміксів усередині кожного жанру

select *
From reading_sessions
Limit 5;

With genres_ranked as(
	Select 
		c.comic_id, 
        c.title,
		c.genre, 
		Count(Distinct r.user_id) as users_count,
		Rank() Over (Partition by c.genre Order by Count(Distinct r.user_id) desc) as genre_rank
	From comics c 
	Left join episodes e on c.comic_id = e.comic_id
	Left join reading_sessions r on e.episode_id = r.episode_id
	Group by c.comic_id
)
Select
	comic_id,
	title,
    genre,
    users_count,
    genre_rank
From genres_ranked
Order by genre, genre_rank
;

# Завдання 25 — попередня успішна оплата через LAG()
Select
	user_id,
    payment_id,
    completed_at,
    Lag(completed_at) Over (Partition by user_id Order by completed_at asc) as previous_payment_at,
    TIMESTAMPDIFF(DAY, Lag(completed_at) Over (Order by completed_at asc), completed_at) as days_since_previous
From payments
Where status = "succeeded"
Order by user_id, completed_at, payment_id
;

#Красивіше через CTE
With succeeded_payments_by_customer As (
	Select
		user_id,
		payment_id,
		completed_at,
		Lag(completed_at) Over (Partition by user_id Order by completed_at asc) as previous_payment_at
	From payments
	Where status = "succeeded"
)
Select
	user_id,
    payment_id,
    completed_at,
    previous_payment_at,
    timestampdiff(Day, previous_payment_at, completed_at) as day_since_previous
From succeeded_payments_by_customer
Order by user_id
;
# Завдання 26 — наступний сеанс читання через LEAD()
-- Для кожного сеансу читання виведи:
-- - user_id;
-- - session_id;
-- - started_at;
-- - next_session_at — початок наступного сеансу цього користувача;
-- - hours_until_next — кількість повних годин між початками поточного та наступного сеансів.
-- Умови:
-- - Таблиця: reading_sessions.
-- - Порядок сеансів: started_at, потім session_id.
-- - Наступний сеанс може стосуватися будь-якого епізоду.
-- - Для останнього сеансу користувача наступна дата й інтервал — NULL.

With next_read_session as(
	Select 
		user_id,
		session_id,
		started_at,
		Lead(started_at) Over (Partition by user_id Order by started_at) as next_session_at
	From reading_sessions
)
Select 
	user_id,
	session_id,
	started_at,
    next_session_at,
    Timestampdiff(Hour, started_at, next_session_at) as hours_to_next_read_session
From next_read_session
order by user_id, started_at, session_id
;



-- Завдання 27 — накопичені чисті надходження за днями

-- Для кожної дати, у яку були успішні оплати або повернення, виведи:

-- operation_date — дату без часу;
-- net_cash_usd — успішні оплати мінус повернення за цей день;
-- cumulative_net_cash_usd — накопичену суму від початку періоду до цього дня включно.

With succeeded_payments as (
	Select 
		Date(completed_at) as operation_date,
		Sum(amount_usd) as total_made_per_day
	From payments
	Where status = "succeeded"
	Group by Date(completed_at)
),
refunded_days as(
	Select
		Date(refunded_at) as operation_date,
		Sum(amount_usd) as total_refunded_per_day
	From refunds
	Group by Date(refunded_at)
)
Select
	s.operation_date, 
    Coalesce(s.total_made_per_day,0),
    Coalesce(r.total_refunded_per_day,0),
    (Coalesce(s.total_made_per_day,0) - Coalesce(r.total_refunded_per_day,0)) as net_cash_usd
From succeeded_payments s
Left Join refunded_days r on s.operation_date = r.operation_date
;

## але тут непарильно бо лефт джойн прибере всі дні які були тільки з refunds
With payments_refunds_per_day as(
	Select 
		Date(completed_at) as operation_date,
		Sum(amount_usd) as total_made_per_day,
		0 as total_refunded_per_day
	From payments
	Where status = "succeeded"
	Group by Date(completed_at)

	Union All

	Select
		Date(refunded_at) as operation_date,
		0 as total_made_per_day,
		Sum(amount_usd) as total_refunded_per_day
	From refunds
	Group by Date(refunded_at)

	Order by operation_date
),
operations_date_stat as (
	Select 
		operation_date, 
		Sum(total_made_per_day) as total_made_per_day, 
		Sum(total_refunded_per_day) as total_refunded_per_day
	From payments_refunds_per_day
	Group by operation_date
)
Select
	operation_date,
    total_made_per_day,
    total_refunded_per_day,
    (total_made_per_day-total_refunded_per_day) as net_cash_usd,
    Sum(
		total_made_per_day-total_refunded_per_day) 
		Over (Order by operation_date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
	) as cumulative_net_cash_usd
From operations_date_stat
Order by operation_date


# Другий спосіб: створимо табоицю із датами, поітм лефтджойн для пеймент, лефт джойн для рефандс



-- Завдання 28 — зміна чистих надходжень від місяця до місяця
-- Для кожного місяця із січня по червень 2026 року виведи:
-- - month_start — перший день місяця;
-- - net_cash_usd — успішні оплати мінус повернення;
-- - previous_month_net — чисті надходження попереднього місяця;
-- - change_usd — зміна в доларах;
-- - change_pct — зміна у відсотках, округлена до 2 знаків.
-- Формули:
-- change_usd = поточний місяць − попередній місяць

-- change_pct = (поточний − попередній) / попередній × 100

-- Умови:
-- - Оплати враховуй за completed_at, повернення — за refunded_at.
-- - Покажи всі 6 місяців, навіть якщо в якомусь немає операцій: його надходження — 0.
-- - Для січня попередній місяць і обидві зміни — NULL.
-- - Якщо попередні надходження дорівнюють нулю, change_pct — NULL.
-- - Відсортуй хронологічно.
;


With unioned_months_revenue_refund as (
	Select 
		Year(completed_at) as year,
		Month(completed_at) as month,
		Min(completed_at) as month_start,
		Sum(amount_usd) as month_total,
		0 as month_refunded_total
	From payments
    Where status = 'succeeded'
	Group by Year(completed_at),Month(completed_at)

	UNION ALL

	Select 
		Year(refunded_at) as year,
		Month(refunded_at) as month,
		Min(refunded_at) as month_start,
		0 as month_total,
		Sum(amount_usd) as month_refunded_total
	From refunds
	Group by Year(refunded_at),Month(refunded_at)

	Order by year, month
),
month_stat as (
	Select
		year,
		month,
		Min(month_start) as month_start,
		Sum(month_total) as month_total,
		Sum(month_refunded_total) as month_refunded_total
	From unioned_months_revenue_refund
	Group by year, month
)
Select 
	year,
	month,
    CAST(
		Concat(year,'-', LPAD(month,2,"0"), '-01') AS DATE
    ) AS month_start,
    month_total,
    month_refunded_total,
    (month_total - month_refunded_total) as net_cash_usd,
    Lag(month_total - month_refunded_total) Over (Order by month_start ASC) as previous_month_net,
    ( month_total - month_refunded_total -  Lag(month_total - month_refunded_total) Over (Order by month_start ASC) ) as change_usd,
    Round(100*((month_total - month_refunded_total)/ Nullif(Lag(month_total - month_refunded_total) Over (Order by month_start ASC),0)   -1   )     ,2) as change_pct
From month_stat
;


-- 01_10_2026
SELECT COunt(*)
FROM reading_sessions
WHERE user_id = 42;
;

SELECT session_id, user_id, episode_id, started_at
FROM reading_sessions
WHERE user_id = 42
  AND started_at >= '2026-05-01'
  AND started_at < '2026-06-01'
ORDER BY started_at, session_id;
;

-- Task 29
Explain
Select *
From reading_sessions
Where user_id = 42
 AND started_at >= '2026-05-01'
  AND started_at < '2026-06-01'
Order by started_at, session_id
;

Show Index from reading_sessions
;

# Now with Index
Create INDEX idx_reading_user_started
ON reading_sessions(user_id, started_at)
;

Explain
Select *
From reading_sessions
Where user_id = 42
 AND started_at >= '2026-05-01'
  AND started_at < '2026-06-01'
Order by started_at, session_id
;


-- Завдання 30 — як DATE() впливає на використання індексу
-- Порівняємо два запити, які знаходять читання за 10 травня 2026 року.
-- 1. Спочатку перевір індекси:
;
EXPLAIN
SELECT *
FROM reading_sessions
WHERE DATE(started_at) = '2026-05-10';

EXPLAIN
SELECT *
FROM reading_sessions
WHERE started_at >= '2026-05-10'
  AND started_at < '2026-05-11';
  
  
  
# lets create an Index
Create Index idx_reading_started
on reading_sessions(started_at)


# Завдання 31 — складений індекс для успішних платежів
-- Знайди успішні платежі за травень 2026 року. Виведи:
-- - payment_id;
-- - user_id;
-- - completed_at;
-- - amount_usd.
;

Explain
Select 
	payment_id,
    user_id,
    completed_at,
    amount_usd
From payments
Where status = 'succeeded' 
	and completed_at >='2026-05-01' 
    and completed_at < '2026-06-01'
  
;
SHOW INDEX FROM payments;
Create Index idx_status_compeleted_at
On payments(status,completed_at)
;

SHOW INDEX FROM payments;
Create Index idx_compeleted_at_status
On payments(completed_at,status)
;

Explain
Select 
	payment_id,
    user_id,
    completed_at,
    amount_usd
From payments
Where completed_at >='2026-05-01' 
    and completed_at < '2026-06-01'
;

Create Index idx_completed_at
on payments(completed_at)
;



# Завдання 22
Select *
From users
;

# дата реєстрації - к-сть зареєстрованих цього дня
Select Date(registered_at) as registered_at , Count(*) as users_registered
From users
Group by Date(registered_at)
Order by Date(registered_at)
;

#дата реєстрації - к-сть людей з них які читали на 7 день
# спочатку чекнемо які сесії читання є у кожного юзера


With users_read_7_day as (
	Select 
		u.user_id,
		Date(u.registered_at) as registered_at,
		Date(r.started_at) as started_at,
		DATEDIFF(r.started_at, u.registered_at ) as read_since_registration
	From users u
	Left Join reading_sessions r on u.user_id = r.user_id
	Where DATEDIFF(r.started_at, u.registered_at ) = 7
	#Order by Date(u.registered_at) ASC
),
users_read_7_day_count as (
	Select 
		registered_at,
		Count(Distinct user_id) as users_count_read_7_day
	From users_read_7_day
	Group by registered_at
),
users_registered_count as ( # К-сть зареєстрованих людей на дату
	Select Date(registered_at) as registered_at , Count(*) as users_registered
	From users
    WHERE registered_at < '2026-06-24'
	Group by Date(registered_at)
	#Order by Date(registered_at)
)
Select
	u_reg.registered_at,
    u_reg.users_registered,
    Coalesce(u_read.users_count_read_7_day,0) as users_count_read_7_day,
    Round((Coalesce(u_read.users_count_read_7_day,0)) * 100 / ( u_reg.users_registered),2) as d7_retention_pct
From users_registered_count u_reg
Left Join users_read_7_day_count u_read on u_reg.registered_at = u_read.registered_at
Order by u_reg.registered_at




#21
-- Залишилося пропущене завдання 21 — баланс монет користувачів 🪙
-- Для кожного користувача, включно з тими, хто нічого не купував і не витрачав, виведи:
-- Колонка	Що порахувати
-- user_id	ID користувача
-- coins_purchased	Сума coins_granted з успішних платежів
-- coins_revoked	Сума монет, забраних через повернення коштів
-- coins_spent	Сума монет, витрачених на відкриття епізодів
-- coin_balance	Куплені − забрані − витрачені
;

# 1)Таблиця із користувачами і Сума coins_granted з успішних платежів
WITH table_coins_purchased as(
	Select
		 u.user_id,
		 Coalesce(Sum(coins_granted),0) as coins_purchased
	From users u
	Left join payments p on u.user_id = p.user_id and status = 'succeeded'
	Group by u.user_id
),
# 2) Таблиця із користувачами і Сума монет, забраних через повернення коштів
table_coins_revoked as (
	Select
		u.user_id,
		Coalesce(Sum(r.coins_revoked),0) as coins_revoked
	From users u
	Left join payments p on u.user_id = p.user_id and status = 'succeeded'
	Left join refunds r on p.payment_id = r.payment_id
	Group by u.user_id
),
# Сума монет, витрачених на відкриття епізодів
table_coins_spent as(
	Select
		user_id,
		Coalesce(Sum(coins_spent),0) as coins_spent
	From episode_unlocks
	Group by user_id
)
Select 
	pur.user_id,
	pur.coins_purchased,
    rev.coins_revoked,
    Coalesce(sp.coins_spent,0) as coins_spent,
    (pur.coins_purchased -  rev.coins_revoked - Coalesce(sp.coins_spent,0)) as coin_balance
From table_coins_purchased pur
Left Join table_coins_revoked rev on pur.user_id = rev.user_id
Left Join table_coins_spent sp on pur.user_id = sp.user_id
Order by pur.user_id