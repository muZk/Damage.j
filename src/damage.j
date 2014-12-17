/* By muZk 
        v.0.3
*/

library DamageEvent initializer Init

    define
        private SURVIVAL = 'A065'
        private AMOUNT = 500000
        private MAGIC_DETECT = 'A0I0'
        private REFRESH_TRIGGER = true
        private TRIGGER_REFRESH_PERIOD = 300 // 5 min
        private SHOW = false
    enddefine
    
    globals
        private hashtable ht = InitHashtable()
    endglobals
    
    private bool CanTakeDamage(unit u){
        return GetUnitAbilityLevel(u,'Aloc')==0
    }
    
    public function interface Response takes unit damagedUnit, unit damageSource, real damage returns nothing
    
    
    // Métodos:
    //  Damage.Block(100) para bloquear 100 de daño
    //  Damage.Block(-100) para incrementar el daño en 100
    //  Damage.BlockPercent(10) para bloquear el 10% del daño
    //  Damage.BlockPercent(-10) para incrementar el daño en 10%
    //  Damage.isSpell() para saber si el daño es mágico
    //  Damage.isPhysical() para saber si el daño es físico
    struct Damage extends array
        static int length = 0
        static Response array responses
        static boolean disabled = false
        static int stack = 0
        static real array block
        
        static method BlockPercent takes real percent returns nothing
            thistype.block[thistype.stack] += GetEventDamage()*percent/100
        endmethod
        
        static method Block takes real amount returns nothing
            thistype.block[thistype.stack] += amount
        endmethod
        
        static method survival takes unit u returns nothing
            integer h=GetHandleId(u)
            integer s=LoadInteger(ht,h,0)+1
            if s==1 then
                UnitAddAbility(u,SURVIVAL)
            endif
            SaveInteger(ht,h,0,s)
        endmethod
        
        static method remove takes unit u returns nothing
            integer h=GetHandleId(u)
            integer s=LoadInteger(ht,h,0)-1
            if s<=0 then
                UnitRemoveAbility(u,SURVIVAL)
                RemoveSavedInteger(ht,h,0)
            else
                SaveInteger(ht,h,0,s)
            endif
        endmethod
        
        static method show takes unit u, real x returns nothing
        endmethod
        
    endstruct
    
    // Register a response function
    void RegisterDamageResponse(Response r){
        Damage.responses[Damage.length] = r
        Damage.length++
    }
    
    globals // locals
        private unit Damaged
        private real Life
        private integer Index
    endglobals
    
    private struct Physical extends array
        static int stack = 0
        
        static unit array target
        static timer timer = CreateTimer()
        static method remove takes nothing returns nothing
            whilenot(thistype.stack==0){
            
                Damaged=thistype.target[thistype.stack]
                
                if(GetUnitAbilityLevel(Damaged,SURVIVAL)==0){
                    BJDebugMsg("Damage-Physical MinimalError "+GetUnitName(Damaged)+ " [ " + I2S(thistype.stack) + " ]")
                }
                //BJDebugMsg("Remove [Physical] "+GetUnitName(Damaged)+ " [ " + I2S(thistype.stack) + " ][" + I2S(GetHandleId(Damaged)) + "]")
                
                Life=GetWidgetLife(Damaged)
                Damage.remove(Damaged)
                //UnitRemoveAbility(Damaged,SURVIVAL)
                if(Life>0.405){
                    SetWidgetLife(Damaged,Life)
                }
                thistype.stack--
            }
        endmethod
    endstruct
    
    private struct Magical extends array
        static int stack = 0
        static unit array target
        static unit array source
        static real array delta
        static timer timer = CreateTimer()
        static method remove takes nothing returns nothing
            Index=0
            whilenot(Index==thistype.stack){
                Damaged=thistype.target[Index]
                
                if(GetUnitAbilityLevel(Damaged,SURVIVAL)==0){
                    BJDebugMsg("Damage-Magical MinimalError "+GetUnitName(Damaged)+ " [ " + I2S(thistype.stack) + " ][" + I2S(GetHandleId(Damaged)) + "]")
                }
                
                //BJDebugMsg("Remove [Magical] "+GetUnitName(Damaged)+ " [ " + I2S(thistype.stack) + " ][" + I2S(GetHandleId(Damaged)) + "]")
                
                Life=GetWidgetLife(Damaged)-2*thistype.delta[Index]
                Damage.remove(Damaged)
                //UnitRemoveAbility(Damaged,SURVIVAL)
                
                if(Life > 0.405){
                    SetWidgetLife(Damaged,Life)
                } else { 
                    SetWidgetLife(Damaged,0.406)
                    Damage.disabled = true
                    UnitDamageTarget(thistype.source[Index],Damaged,-1000,false,false,ATTACK_TYPE_NORMAL,DAMAGE_TYPE_UNIVERSAL,null)
                    Damage.disabled = false
                }
                Index++
            }
            thistype.stack = 0
        endmethod
    endstruct
    
    bool UnitDamageTargetEx(unit source, widget target, real amount, boolean attack, boolean ranged, attacktype attackType, damagetype damageType, weapontype weaponType){
        Damage.stack++
        bool result = UnitDamageTarget(source,target,amount,attack,ranged,attackType,damageType,weaponType)
        Damage.stack--
        return result
    }
    
    void Damage_Block(real amount){
        Damage.Block(amount)
    }
    
    void Damage_BlockAll(){
        real d=GetEventDamage()
        if(d>0){
            Damage.Block(d)
        } else {
            Damage.Block(-d)
        }
    }
    
    // WRAPPERS
    
    define
        Damage_Spell(u,t,d) = UnitDamageTargetEx(u,t,d,false,false,ATTACK_TYPE_NORMAL,DAMAGE_TYPE_MAGIC,null)
        Damage_Physical(u,t,d) = UnitDamageTargetEx(u,t,d,false,false,ATTACK_TYPE_MELEE,DAMAGE_TYPE_NORMAL,null)
        Damage_Register(r) = RegisterDamageResponse(r)
    enddefine
    
    bool Damage_IsPhysical(){
        return GetEventDamage() > 0
    }
    bool Damage_IsAttack(){
        return GetEventDamage() > 0
    }
    bool Damage_IsSpell(){
        return GetEventDamage() < 0
    }
    
    private boolean onDamage(){
        unit u=GetTriggerUnit()
        unit d=GetEventDamageSource()
        real damage=GetEventDamage()
        real damageMod=RAbsBJ(damage)
        int index=0
        bool execute=false
        
        if(damageMod<1){
            return false
        }
        if(Damage.disabled){
            return false
        }
        
        // Ejecutar eventos

        whilenot(index==Damage.length){
            Damage.responses[index].evaluate(u,d,damage)
            index++
        }
        
        // Calcular siguiente HP
        real block = Damage.block[Damage.stack]
        real hp = GetWidgetLife(u)
        real nextHealth
        
        // Blocking
        if(block > 0){
        
            if(block>=damageMod){
                block=damageMod
            }
        
            nextHealth = hp + block
            
            SetWidgetLife(u,nextHealth)
            if(GetWidgetLife(u)<nextHealth){
                Damage.survival(u)
                SetWidgetLife(u,nextHealth)
                execute=true
            }
            
            if(damage<0){
                nextHealth += 2*damage
                if(nextHealth >= 0.405){
                    SetWidgetLife(u,nextHealth)
                    damage = -damage
                }
            }
            
        }
    
        if(damage<0){ 
            hp = GetWidgetLife(u)
            if not execute then
                Damage.survival(u)
            endif
            SetWidgetLife(u,hp)
            
            Magical.delta[Magical.stack] = damageMod
            Magical.target[Magical.stack] = u
            Magical.source[Magical.stack] = d
            Magical.stack++
            TimerStart(Magical.timer,0.0,false,function Magical.remove)
        } else {
            if(execute){
                Physical.stack++
                Physical.target[Physical.stack] = u
                TimerStart(Physical.timer,0.0,false,function Physical.remove)
            }
        }
        
        if GetEventDamage()<0 then
            Damage.show(u,GetEventDamage()+block)
        else
            Damage.show(u,GetEventDamage()-block)
        endif
        
        if block > 0 then
            Damage.block[Damage.stack] = 0
        endif
        
        d=null
        u=null
        return false
    }
    
// ================================================================
    // Code "borrowed" from http://www.wc3c.net/showthread.php?t=108009
    // DamageEvent By Anitarf
    globals
        private group g
        private boolexpr b
        private boolean clear
        
        public trigger currentTrg
        private triggeraction currentTrgA
        private trigger oldTrg = null
        private triggeraction oldTrgA = null
    endglobals
    private void TriggerRefreshEnum(){
        // Code "borrowed" from Captain Griffen's GroupRefresh function.
        // This clears the group of any "shadows" left by removed units.
        if clear then
            call GroupClear(g)
            set clear = false
        endif
        call GroupAddUnit(g, GetEnumUnit())
        // For units that are still in the game, add the event to the new trigger.
        call TriggerRegisterUnitEvent( currentTrg, GetEnumUnit(), EVENT_UNIT_DAMAGED )
    }
    private void TriggerRefresh(){
        // The old trigger is destroyed with a delay for extra safety.
        // If you get bugs despite this then turn off trigger refreshing.
        if oldTrg!=null then
            call TriggerRemoveAction(oldTrg, oldTrgA)
            call DestroyTrigger(oldTrg)
        endif
        // The current trigger is prepared for delayed destruction.
        call DisableTrigger(currentTrg)
        set oldTrg=currentTrg
        set oldTrgA=currentTrgA
        // The current trigger is then replaced with a new trigger.
        set currentTrg = CreateTrigger()
        set currentTrgA = TriggerAddAction(currentTrg, function onDamage)
        set clear = true
        call ForGroup(g, function TriggerRefreshEnum)
        if clear then
            call GroupClear(g)
        endif
    }
    
    private bool DamageRegister(){
        unit u = GetFilterUnit()
        if CanTakeDamage(u) then
            TriggerRegisterUnitEvent( currentTrg, u, EVENT_UNIT_DAMAGED )
            UnitAddAbility(u,MAGIC_DETECT)
            UnitMakeAbilityPermanent(u,true,MAGIC_DETECT)
            GroupAddUnit(g, u)
        endif
        u = null
        return false
    }
    
    private void Init(){
        rect rec = GetWorldBounds()
        region reg = CreateRegion()
        trigger t = CreateTrigger()
        RegionAddRect(reg, rec)
        TriggerRegisterEnterRegion(t, reg, Condition(function DamageRegister))
        
        set currentTrg = CreateTrigger()
        set currentTrgA = TriggerAddAction(currentTrg, function onDamage)

        set g = CreateGroup()
        call GroupEnumUnitsInRect(g, rec, Condition(function DamageRegister))
        
        if REFRESH_TRIGGER then
            call TimerStart(CreateTimer(), TRIGGER_REFRESH_PERIOD, true, function TriggerRefresh)
        endif
        
        RemoveRect(rec)
        set rec = null
        set b = null
        set t=null
    }

endlibrary