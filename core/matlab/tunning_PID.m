%% ============================================================
%  SYSTEM IDENTIFICATION - Clean Open-Loop SysID Data
%% ============================================================
clear; clc; close all;

%% --- 1. READ DATA FILE ---
filename = 'G:\My Drive\Study\Spring (2025-2026)\Senior\matlab\sysid_data.csv'; 
T_raw = readtable(filename);

% Check actual column names
disp('Raw Column Names:');
disp(T_raw.Properties.VariableNames);

% Standardize names — assuming columns: timestamp, SYSID_START, SysID_PWM, SysID_Enc
T_raw.Properties.VariableNames = {'ts','SYSID_START','SysID_PWM','SysID_Enc','Target','Encoder','State','Error','PWM'};
fprintf('Total raw rows: %d\n', height(T_raw));

%% --- 2. FORWARD-FILL PWM AND ENCODER COLUMNS ---
pwm_col = T_raw.SysID_PWM;
enc_col = T_raw.SysID_Enc;
for i = 2:length(pwm_col)
    if isnan(pwm_col(i)); pwm_col(i) = pwm_col(i-1); end
    if isnan(enc_col(i)); enc_col(i) = enc_col(i-1); end
end
T_raw.SysID_PWM = pwm_col;
T_raw.SysID_Enc = enc_col;

%% --- 3. FILTER SYSID REGION (PWM = 450, Encoder increasing) ---
% Remove SYSID_START marker and subsequent PID data
idx_sysid = (T_raw.SysID_PWM == 450) & ~isnan(T_raw.SysID_Enc);
T_sysid = T_raw(idx_sysid, :);
fprintf('SysID rows: %d\n', height(T_sysid));

%% --- 4. REMOVE DUPLICATE ENCODER VALUES ---
enc = T_sysid.SysID_Enc;
keep = [true; diff(enc) ~= 0];
T_clean = T_sysid(keep, :);
fprintf('Data points after deduplication: %d\n', height(T_clean));

%% --- 5. RECONSTRUCT TIMELINE (Ts = 10ms) ---
Ts = 0.01;
n = height(T_clean);
time_s    = (0:n-1)' * Ts;
enc_filt  = T_clean.SysID_Enc - T_clean.SysID_Enc(1);  % Reset to 0
pwm_filt  = T_clean.SysID_PWM;
fprintf('Measurement time: %.2f seconds | Final Encoder value: %d\n', time_s(end), enc_filt(end));

%% --- 6. PLOT TO VERIFY DATA ---
figure('Name','SysID Data - Open Loop','NumberTitle','off');
subplot(2,1,1);
plot(time_s, pwm_filt, 'b', 'LineWidth', 2);
ylabel('PWM'); xlabel('Time (s)');
title(sprintf('System Input: Constant PWM = 450 | %d points', n));
ylim([0 600]); grid on;

subplot(2,1,2);
plot(time_s, enc_filt, 'r', 'LineWidth', 2);
ylabel('Encoder counts'); xlabel('Time (s)');
title('System Output: Encoder Position (Reset to 0)');
grid on;

%% --- 7. SYSTEM IDENTIFICATION (TRANSFER FUNCTION) ---
n_tr = round(0.6 * n);
fprintf('\nTraining set: %d | Validation set: %d points\n', n_tr, n - n_tr);
d_train = iddata(enc_filt(1:n_tr),     pwm_filt(1:n_tr),     Ts);
d_val   = iddata(enc_filt(n_tr+1:end), pwm_filt(n_tr+1:end), Ts);

opt = tfestOptions('Display','off');
fprintf('Identifying models...\n');

sys21 = tfest(d_train, 2, 1, opt);
sys20 = tfest(d_train, 2, 0, opt);
sys11 = tfest(d_train, 1, 0, opt);   % Try simple 1st order

[~, fit21] = compare(d_val, sys21);
[~, fit20] = compare(d_val, sys20);
[~, fit11] = compare(d_val, sys11);

fprintf('\n--- Fit Results ---\n');
fprintf('TF(1 pole, 0 zero): %.1f%%\n', fit11);
fprintf('TF(2 poles, 0 zero): %.1f%%\n', fit20);
fprintf('TF(2 poles, 1 zero): %.1f%%\n', fit21);

% Select the best model
fits   = [fit11, fit20, fit21];
models = {sys11, sys20, sys21};
names  = {'TF(1p,0z)','TF(2p,0z)','TF(2p,1z)'};
[best_fit, idx] = max(fits);
best = models{idx}; best_name = names{idx};

fprintf('✓ Best model selected: %s  Fit = %.1f%%\n\n', best_name, best_fit);
disp(best);

%% --- 8. PLOT VALIDATION RESULTS ---
figure('Name','Model Validation','NumberTitle','off');
compare(d_val, sys11, sys20, sys21);
legend('Measured Data','TF(1p)','TF(2p,0z)','TF(2p,1z)');
title('System Identification: Mathematical Model vs Measured Data'); grid on;

%% --- 9. AUTO TUNING PID ---
% Test multiple CrossoverFrequency and PhaseMargin values
cf_list = [2, 3, 4, 5, 6, 8];
pm_list = [50, 55, 60, 65, 70];
results = [];

for cf = cf_list
    for pm = pm_list
        try
            opts = pidtuneOptions('CrossoverFrequency', cf, 'PhaseMargin', pm);
            C    = pidtune(best, 'pid', opts);
            sys_cl = feedback(C * best, 1);
            info   = stepinfo(515 * sys_cl);
            
            % Keep only stable and satisfactory solutions
            p = pole(sys_cl);
            if all(real(p) < 0) && info.Overshoot < 10 && info.SettlingTime < 2.0
                results(end+1,:) = [cf, pm, C.Kp, C.Ki, C.Kd, ...
                                    info.SettlingTime, info.Overshoot, info.RiseTime];
            end
        catch
        end
    end
end

% Print satisfactory results
fprintf('\n%-4s %-4s %-8s %-8s %-8s %-12s %-10s %-10s\n', ...
    'CF','PM','Kp','Ki','Kd','SettlingTime','Overshoot','RiseTime');
fprintf('%s\n', repmat('-',1,70));
for i = 1:size(results,1)
    fprintf('%-4.0f %-4.0f %-8.4f %-8.4f %-8.4f %-12.3f %-10.1f %-10.3f\n', ...
        results(i,:));
end

% Select the best candidate: prioritize minimum settling time
if isempty(results)
    fprintf('\nNo candidate meets the requirements — please relax constraints\n');
else
    [~, best_idx] = min(results(:,6));  % min SettlingTime
    best_row = results(best_idx, :);
    
    fprintf('\n✓ BEST CONTINUOUS PARAMETERS:\n');
    fprintf('  Kp = %.4f\n', best_row(3));
    fprintf('  Ki = %.4f\n', best_row(4));
    fprintf('  Kd = %.4f\n', best_row(5));
    fprintf('  Settling time = %.3f s\n', best_row(6));
    fprintf('  Overshoot     = %.1f%%\n',  best_row(7));
    fprintf('  Rise time     = %.3f s\n',  best_row(8));
    
    % Plot step response for the best candidate
    opts_best = pidtuneOptions('CrossoverFrequency', best_row(1), ...
                               'PhaseMargin',        best_row(2));
    C_best  = pidtune(best, 'pid', opts_best);
    sys_best = feedback(C_best * best, 1);
    
    figure('Name','Step Response Comparison','NumberTitle','off');
    t = 0:0.01:3;
    
    % Compare with manual parameters
    Kp_old=2.2; Ki_old=1.05; Kd_old=0.55;
    C_old   = pid(Kp_old, Ki_old, Kd_old);
    sys_old = feedback(C_old * best, 1);
    info_old = stepinfo(515 * sys_old);
    
    y_old = step(515 * sys_old,  t);
    y_new = step(515 * sys_best, t);
    
    plot(t, y_old, 'r--', 'LineWidth', 1.5); hold on;
    plot(t, y_new, 'b',   'LineWidth', 2);
    yline(515, 'k:', 'Target');
    yline(515*1.05,  'g:',  '+5% Error Band');
    yline(515*0.95,  'g:',  '-5% Error Band');
    
    xlabel('Time (s)'); ylabel('Encoder counts');
    legend(sprintf('Manual Tuning: ST=%.2fs OS=%.1f%%', info_old.SettlingTime, info_old.Overshoot), ...
           sprintf('Optimized PID: ST=%.2fs OS=%.1f%%', best_row(6), best_row(7)), ...
           'Target', 'Location', 'Southeast');
    title('Closed-Loop Step Response: Manual vs Optimized PID'); grid on;
end

%% --- 10. AUTOMATIC DISCRETE CONVERSION FOR C CODE ---
% Get continuous parameters from MATLAB
Kp_matlab = C_best.Kp;
Ki_matlab = C_best.Ki;
Kd_matlab = C_best.Kd;

% Convert using sampling time Ts = 0.01s for STM32
Kp_code = Kp_matlab;
Ki_code = Ki_matlab * Ts;
Kd_code = Kd_matlab / Ts;

fprintf('\n======================================================\n');
fprintf('  CONVERTED PARAMETERS FOR STM32 C CODE (Ts = %.2fs)\n', Ts);
fprintf('======================================================\n');
fprintf('float Kp = %.4ff;\n', Kp_code);
fprintf('float Ki = %.4ff;\n', Ki_code);
fprintf('float Kd = %.4ff;\n', Kd_code);
fprintf('======================================================\n\n');

% Safety warning for Derivative gain
if (Kd_code > 10)
    fprintf('⚠️ NOTE: The discrete Kd (%.2f) is quite large.\n', Kd_code);
    fprintf('Please start testing hardware with float Kd = 2.0f;\n');
    fprintf('Then gradually increase it if the motor still overshoots.\n');
end