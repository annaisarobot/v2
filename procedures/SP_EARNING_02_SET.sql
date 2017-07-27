DROP PROCEDURE SP_EARNING_02_SET;
create Procedure Commissions.sp_Earning_02_Set(
					 pn_Period_id		int
					,pn_Period_Batch_id	int)
   LANGUAGE SQLSCRIPT
   DEFAULT SCHEMA Commissions
AS
    
Begin
    declare ln_Max_Lvl	integer;
    declare ln_count    integer = 1;
    declare ln_x        integer = 1;
    declare ln_y        integer;
    
	Update period_batch
	Set beg_date_Earning_2 = current_timestamp
      ,end_date_Earning_2 = Null
   	Where period_id = :pn_Period_id
   	and batch_id = :pn_Period_Batch_id;
   	
   	commit;
		
	-- Get Exchange Rates
	lc_Exchange = 
		select *
		from gl_Exchange(:pn_Period_id);
		
	-- Get Customer Type
	lc_Customer_Type =
		select *
		from customer_type;
		
	-- Get Customer Status
	lc_Customer_Status =
		select *
		from customer_status;
		
	-- Get Customer Flags
	lc_Customer_Flag =
		select *
		from gl_Customer_Flag(0, :pn_Period_id);
		
	-- Get Versions
	lc_Version =
		select *
		from version
		where version_id in (1,2);
   	
   	-- Get Period Customers
    lc_Customers_Level = 
    	select 
			 c.customer_id													as customer_id
			,c.sponsor_id													as sponsor_id
			,c.period_id													as period_id
			,c.batch_id														as batch_id
			,c.type_id														as type_id
			,c.country														as country
			,e.currency														as currency
			,map(e.currency,'KRW',1000,e.rate)								as exchange_rate
			,e.round_factor													as round_factor
			,ifnull(c.comm_status_date,
				case when ifnull(t1.has_faststart,0) = 1 then c.entry_date						-- Type Wellness, Professional and Wholesale default to entry_date
				else to_date('1/1/2000','mm/dd/yyyy') end) 					as comm_status_date -- All other default to 1/1/2000
			,c.entry_date													as entry_date
			,ifnull(v.version_id,1)											as version_id
			,vol_1+vol_4													as qv
			,vol_1															as pv
			,vol_2															as pv_lrp
			,vol_12															as egv_lrp
			,vol_14															as tv
			,map(ifnull(f6.flag_type_id,0),6,1,0) 							as pv_lrp_waiver
			,map(ifnull(f7.flag_type_id,0),7,1,0) 							as tv_waiver
		from customer_history c
			left outer join :lc_Customer_Type t1
				on c.type_id = t1.type_id
		   	left outer join :lc_Customer_Status s1
		   		on c.status_id = s1.status_id
		   	left outer join :lc_Customer_Flag f6
				on f6.customer_id = c.customer_id
				and f6.flag_type_id = 6
			left outer join :lc_Customer_Flag f7
				on f7.customer_id = c.customer_id
				and f7.flag_type_id = 7
			left outer join :lc_Version v
				on c.country = v.country
    		left outer join :lc_Exchange e
    			on e.currency = ifnull((select max(flag_value)
										  from :lc_Customer_Flag
										  where customer_id = c.customer_id
										  and flag_type_id = 2),c.currency)
		where c.period_id = :pn_Period_id
		and c.batch_id = :pn_Period_Batch_id
		and ifnull(t1.has_power3,-1) = 1
		and ifnull(s1.has_earnings,-1) = 1;
	    
	-- Get Requirements for Power3
	lc_Req_Power3 =
		select *
		from earning_02_req
		where period_id = :pn_Period_id
		and batch_id = :pn_Period_Batch_id;
		
	-- Get Max Structure Level
	select max(level_id)
	into ln_Max_Lvl
	from :lc_Req_Power3;
    
    while :ln_count <> 0 do
			
	    -- Loop through all tree levels from bottom to top
	    for ln_y in 1..:ln_Max_Lvl do
			replace Earning_02 (period_id, batch_id, sponsor_id, customer_id, lvl_id, paid_lvl_id, from_currency, to_currency, exchange_rate)
	    	select 
	    		 c.period_id
	    		,c.batch_id 
	    		,c.sponsor_id		as Sponsor_id
	    		,c.customer_id		as Customer_id
	    		,:ln_y 				as Lvl_id
	    		,:ln_x				as Paid_Lvl_id
	    		,'USD'				as from_currency
	    		,c.currency			as to_currency
	    		,c.exchange_rate	as exchange_rate
	    	from :lc_Customers_Level c
	    		, :lc_Req_Power3 r
	    	where c.version_id = r.version_id
	    	and r.level_id = :ln_y
		   	and (c.pv_lrp >= (r.value_1 * :ln_x) or c.pv_lrp_waiver = 1 or (c.version_id = 2 and c.egv_lrp >= (r.value_3 * :ln_x))) -- or case when :ln_x > 1 then c.pv else c.pv_lrp end >= (r.value_1 * :ln_x))
		   	and (c.tv >= (r.value_2 * :ln_x) or c.tv_waiver = 1)
		   	and (select count(*)
		   		 from Earning_02
		   		 where period_id = :pn_Period_id
				 and batch_id = :pn_Period_Batch_id
				 and sponsor_id = c.customer_id
		   		 and (lvl_id >= r.structure_level 
		   		  or paid_lvl_id > 1)) >= (r.structure_count * :ln_x);
			
	        commit;
	    end for;
	    
	    lc_Customers_Level = 
	    	select *
	    	from :lc_Customers_Level
	    	where customer_id in (
	    		select customer_id		  
			    from Earning_02
			    where period_id = :pn_Period_id
				and batch_id = :pn_Period_Batch_id
				and paid_lvl_id = :ln_x
			    and lvl_id = :ln_Max_Lvl);
	    
	    select count(*)
	    into ln_count
	    from :lc_Customers_Level;
	    
	    ln_x = :ln_x + 1;
    end while;
    
    -- Set Earning Amou :pn_Period_Batch_id) a
			left outer join customer_type at
			 	on at.type_id = a.type_id
			left outer join gl_Exchange(:pn_Period_id) x2
			  	on x2.currency = a.currency
			left outer join customer_type t2
			  	on a.type_id = t2.type_id
			, gl_Volume_Pv_Detail(:pn_Period_id, :pn_Period_Batch_id) t
		Where t.customer_id = a.customer_id
		and c.customer_id = a.sponsor_id
		And ifnull(t2.has_retail,-1) = 1
		And ifnull(t1.has_downline,-1) = 1;
	--end if;
	
end; urrency				varchar(5)
			,pv							decimal(18,8)
			,cv							decimal(18,8))
	LANGUAGE SQLSCRIPT
	SQL SECURITY INVOKER
   	DEFAULT SCHEMA Commissions
AS

begin
	/*
	if gl_Period_isOpen(:pn_Period_id) = 1 then
		return
		Select 
		      t.period_id
		     ,t.batch_id
		     ,t.customer_id
		     ,t.transaction_id
		     ,t.transaction_ref_id
		     ,t.type_id
		     ,t.category_id
		     ,t.entry_date
		     ,t.order_number
		     ,t.from_country
		     ,t.from_currency
		     ,t.to_currency
		     ,t.pv
		     ,t.cv
		From  gl_Volume_Pv_Detail(:pn_Period_id, :pn_Period_Batch_id) t
			  left outer join gl_Volume_Pv_Detail(:pn_Period_id, :pn_Period_Batch_id) r
			  on t.transaction_ref_id = r.transaction_id
			, customer c
			  left outer join customer_type t1
			  on c.type_id = t1.type_id
	   	Where t.customer_id = c.customer_id
	   	And t.period_id = :pn_Period_id
	   	And ifnull(t1.has_downline,-1) = 1
	   	and ifnull(t.type_id,4) <> 0
	   	And days_between(ifnull(c.comm_status_date,c.entry_date),ifnull(r.entry_date,t.entry_date)) <= 60;
	else
	*/
		return
		Select 
		      t.period_id
		     ,t.batch_id
		     ,t.cust