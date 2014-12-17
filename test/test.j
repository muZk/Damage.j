scope Test initializer Init

    globals
        private int test_number = 0
        private unit target
        private unit source
        private real life
        private real next
    endglobals
    
    private function assertEquals takes real a, real b, string msg returns nothing
        if a != b then
            BJDebugMsg("[ERROR] "+msg)
        else
            BJDebugMsg("[PASSED] "+msg)
        endif
    endfunction
    
    private function onDamage takes unit t, unit s, real damage returns nothing
        if(test_number == 1){
            Damage_Block(20)
        } elseif(test_number == 2){
            Damage_Block(10)
        } elseif(test_number == 3){
            Damage_BlockAll()
        }
    endfunction
    
    void MainTest(){
        target = gg_unit_hfoo_0001
        source = gg_unit_Hmkg_0002
        BJDebugMsg("=== TEST ===")
        PolledWait(1)
        BJDebugMsg("START...")
        // SIMPLE MAGIC DAMAGE
        life = GetWidgetLife(target)
        Damage_Spell(source, target, 20)
        PolledWait(0.5)
        assertEquals(life - 20, GetWidgetLife(target), "Simple magic damage")
        // DOUBLE
        life = GetWidgetLife(target)
        Damage_Spell(source, target, 5)
        Damage_Spell(source, target, 5)
        PolledWait(0.5)
        assertEquals(life - 10, GetWidgetLife(target), "Double magic damage")
        // SIMPLE BLOCK
        test_number = 1
        life = GetWidgetLife(target)
        Damage_Spell(source, target, 20)
        PolledWait(0.5)
        assertEquals(life, GetWidgetLife(target), "Simple damage block")
        // BLOCK DOUBLE DAMAGE
        test_number = 2
        life = GetWidgetLife(target)
        Damage_Spell(source, target, 5)
        Damage_Spell(source, target, 5)
        PolledWait(0.5)
        assertEquals(life, GetWidgetLife(target), "Block double damage")
        // BLOCK ALL 10.000 damage
        test_number = 3
        life = GetWidgetLife(target)
        Damage_Spell(source, target, 10000)
        PolledWait(0.5)
        assertEquals(life, GetWidgetLife(target), "Block 10k damage")
    }

    public function Init takes nothing returns nothing
        call RegisterDamageResponse(onDamage)
        trigger t = CreateTrigger()
        TriggerAddAction(t, function MainTest)
        TriggerExecute(t)
    endfunction

endscope