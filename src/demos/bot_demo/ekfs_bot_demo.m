% Bearings Only Tracking (BOT) demonstration with EKF

% Copyright (C) 2002 Simo S�rkk�
%               2007 Jouni Hartikainen
%
% $Id: ekfs_demo1.m,v 1.6 2006/10/10 20:18:51 ssarkka Exp $
%
% This software is distributed under the GNU General Public 
% Licence (version 2 or later); please refer to the file 
% Licence.txt, included with the software, for details.

  keep_trajectory = 0;
  silent = 0;
  
  % Number of steps to advance at a time in animations. 
  steps = 2;
  
  % Handles to measurement model function and it's derivatives
  h_func = @az_h;
  dh_dx_func = @az_dh_dx;
  d2h_dx2_func = @az_d2h_dx2;

  % Create a bit curved trajectory and angle
  % measurements from two sensors
  S1 = [-1;-2];
  S2 = [1;1];
  sd = 0.05;
  dt = 0.01;
  if ~keep_trajectory
    % Accelerations for the object
    a = zeros(1,500);
    a(1,50:100)  = pi/2/51/dt + 0.01*randn(1,51);
    a(1,200:250) = pi/2/51/dt + 0.01*randn(1,51);
    a(1,350:400) = pi/2/51/dt + 0.01*randn(1,51);
    x = [0;0;1;0];
    t = 0;
    X = [];
    Y = [];
    T = [];
    for i=1:500
      F = [0 0  1    0;...
           0 0  0    1;...
           0 0  0   a(i);...
           0 0 -a(i) 0];
      x = expm(F*dt)*x;
      y1 = atan2(x(2)-S1(2), x(1)-S1(1)) + sd * randn;
      y2 = atan2(x(2)-S2(2), x(1)-S2(1)) + sd * randn;
      t  = t + dt;
      X = [X x];
      T = [T t];
      Y = [Y [y1;y2]];
    end
  end
  
  % Uncomment if you want to plot and print the measurements
  %plot(1:size(Y,2),Y(1,:),'.',1:size(Y,2),Y(2,:),'.');
  %legend('Sensor 1', 'Sensor 2');
  %title('Measurements from sensors in radians');
  %print -dpsc bot_demo_measurements.ps

  %
  % Initialize EKF to values
  %
  %   x = 0
  %   y = 0,
  %   dx/dt = 0
  %   dy/dt = 0
  %
  % with great uncertainty in velocity
  %
  M = [0;0;0;0];
  P = diag([4 4 4 4]);
  R = sd^2;
  if ~silent
    der_check(h_func, dh_dx_func, 1, M, S1);
    der_check(h_func, dh_dx_func, 1, M, S2);
  end
  qx = 0.1;
  qy = 0.1;
  F = [0 0 1 0;
       0 0 0 1;
       0 0 0 0;
       0 0 0 0];
  [A,Q] = lti_disc(F,[],diag([0 0 qx qy]),dt);

  clc;
  clf;
  disp(['In this demonstration we track a moving object with two sensors, ',...
        'which gives only bearings of the object with respect to sensors position.',...
       'The state of the system is estimated with EKF.'])
  disp(' ');
  fprintf('Running EKF...')
  
  %
  % Track and animate
  %
  MM = zeros(size(M,1),size(Y,2));
  PP = zeros(size(M,1),size(M,1),size(Y,2));
  ME = zeros(size(M,1),1);
  for k=1:size(Y,2)
    % Track with EKF
    [M,P] = ekf_predict1(M,P,A,Q);
    [M,P] = ekf_update1(M,P,Y(:,k),dh_dx_func,R*eye(2),h_func,[],[S1 S2]);
    MM(:,k)   = M;
    PP(:,:,k) = P;
    ME(k) = P(1,1) + P(2,2);
  end
  ekf_rmse = sqrt(mean((X(1,:)-MM(1,:)).^2+(X(2,:)-MM(2,:)).^2));

  fprintf('Done!\n')
  disp(' ');
  disp(['The filtering results are now displayed sequentially. ',...
       'Notice how the estimates gets more accurate when the filter gets on the right track. ',...
       'The green ellipse around the current estimate (little blue circle) reflects the filters ',...
       'confidence intervals of the position estimate.']);
  disp(' ');
  disp('<push any key to proceed>');
  
  % Plot the filtered estimates sequentially
  if ~silent
      M = MM(:,1);  
      P = PP(:,:,1);
      EST = M;
      tt = (0:0.01:1)*2*pi;
      cc = repmat(M(1:2),1,length(tt)) + ...
        	  2*chol(P(1:2,1:2))'*[cos(tt);sin(tt)];
      h = plot(X(1,:),X(2,:),'r-',...
               M(1),M(2),'bo',...
               EST(1,:),EST(2,:),'b--',...
               cc(1,:),cc(2,:),'g-',...
               S1(1),S1(2),'k--',...
               S1(1),S1(2),'k^',...
               S2(1),S2(2),'k--',...
               S2(1),S2(2),'k^');
      legend('Location','NorthWest','Real trajectory','Current estimate','Estimated trajectory',...
             'Confidence interval','Measurements from sensors','Positions of the sensors');
      title('Bearings Only Tracking with EKF.')
      axis([-1.5 1.5 -2.5 1.5]);
      
      EST = [];
      for k=1:steps:size(Y,2)
        M = MM(:,k);
        P = PP(:,:,k);
        EST = MM(:,1:k);

        % Confidence ellipse
        cc = repmat(M(1:2),1,length(tt)) + ...
	     2*chol(P(1:2,1:2))'*[cos(tt);sin(tt)];

        % Measurement directions
        len = 2.5;
        dx1 = len*cos(Y(1,k));
        dy1 = len*sin(Y(1,k));
        dx2 = len*cos(Y(2,k));
        dy2 = len*sin(Y(2,k));

        % Update graphics
        set(h(2),'xdata',M(1)); set(h(2),'ydata',M(2));
        set(h(3),'xdata',EST(1,:)); set(h(3),'ydata',EST(2,:)); 
        set(h(4),'xdata',cc(1,:)); set(h(4),'ydata',cc(2,:)); 
        set(h(5),'xdata',[S1(1);S1(1)+dx1]); set(h(5),'ydata',[S1(2);S1(2)+dy1]); 
        set(h(7),'xdata',[S2(1);S2(1)+dx2]); set(h(7),'ydata',[S2(2);S2(2)+dy2]); 
      pause
    end
  end
  
  clc;
  disp(['In this demonstration we track a moving object with two sensors, ',...
        'which gives only bearings of the object with respect to sensors position.',...
       'The state of the system is estimated with EKF.'])
  disp(' ');
  fprintf('Running EKF...Done!\n')
  disp(' ');
  disp(['The filtering results are now displayed sequentially. ',...
       'Notice how the estimates gets more accurate when the filter gets on the right track. ',...
       'The green ellipse around the current estimate (little blue circle) reflects the filters ',...
       'confidence intervals of the position estimate.']);
  disp(' ');
  disp('<push any key to smooth the estimates with ERTS and ETF>');
  pause;
  clc;
  fprintf('Smoothing with ERTS and ETF...');

  %
  % Smoother 1
  %
  [SM1,SP1] = erts_smooth1(MM,PP,A,Q);
  eks_rmse1 = sqrt(mean((X(1,:)-SM1(1,:)).^2+(X(2,:)-SM1(2,:)).^2));
  ME1 = squeeze(SP1(1,1,:)+SP1(2,2,:));


  %
  % Smoother 2
  %
  [SM2,SP2] = etf_smooth1(MM,PP,Y,A,Q,[],[],[],...
		     dh_dx_func,R*eye(2),h_func,[],[S1 S2]);
  eks_rmse2 = sqrt(mean((X(1,:)-SM2(1,:)).^2+(X(2,:)-SM2(2,:)).^2));
  ME2 = squeeze(SP2(1,1,:)+SP2(2,2,:));

  fprintf('Done!\n')
  disp(' ');
  disp(['Smoothing results of ERTS are now displayed sequentially. ',...
        'Notice how the confidence ellipse gets even smaller now.']);
  disp(' ');
  disp('<push any key to proceed>');
  
  % Plot the smoothed estimates sequentially
  if ~silent
    M = SM1(:,1);  
    P = SP1(:,:,1);
    EST = M;
    cc = repmat(M(1:2),1,length(tt)) + ...
	 2*chol(P(1:2,1:2))'*[cos(tt);sin(tt)];
    h = plot(X(1,:),X(2,:),'r-',...
             M(1),M(2),'o',...
             EST(1,:),EST(2,:),'--',...
             cc(1,:),cc(2,:),'g-',...
             MM(1,:),MM(2,:),'b--',...
             S1(1),S1(2),'k^',S2(1),S2(2),'k^');
    legend('Location','NorthWest','Real trajectory','Current estimate','Smoothed trajectory',...
           'Confidence interval','Filter estimate','Positions of the sensors');
    title('Bearings Only Tracking with ERTS.')
    axis([-1.5 1.5 -2.5 1.5]);
    EST = [];
    for k=size(Y,2):-steps:1
      M = SM1(:,k);  
      P = SP1(:,:,k);
      EST = SM1(:,end:-1:k);

      % Confidence ellipse
      cc = repmat(M(1:2),1,length(tt)) + ...
	 2*chol(P(1:2,1:2))'*[cos(tt);sin(tt)];
      
      set(h(2),'xdata',M(1)); set(h(2),'ydata',M(2));
      set(h(3),'xdata',EST(1,:)); set(h(3),'ydata',EST(2,:)); 
      set(h(4),'xdata',cc(1,:)); set(h(4),'ydata',cc(2,:)); 
      pause;
     end
  end
  
  disp(' ')
  disp('<push any key to display all estimates together>')
  pause;
  clc;
  disp('All estimates are now displayed.')

  %
  % Plot all the estimates together
  %
  if ~silent
    plot(X(1,:),X(2,:),'k-',...
         MM(1,:),MM(2,:),'b--',...
         SM1(1,:),SM1(2,:),'r-.',...
         SM2(1,:),SM2(2,:),'g-.',...
         S1(1),S1(2),'k^',S2(1),S2(2),'k^');
    axis([-1.5 1.5 -2.5 1]);
    legend('Real trajectory',...
           'EKF1 estimate',...
           'ERTS estimate',...
           'ETF estimate',...
           'Positions of sensors',...
           'Location', 'NorthWest');
    title('Filtering and smoothing result with 1st order EKF');
    axis([-1.5 1.5 -2.5 1.5]);
    % Uncomment if you want to save an image
    %print -dpsc bot_demo_ekf1.ps
  end
  
  % Print RMSE
  disp(' ');
  disp('RMS errors:');
  fprintf('EKF-RMSE  = %.3f  [%.3f]\n',ekf_rmse,sqrt(mean(ME)));
  fprintf('EKS-RMSE1 = %.4f [%.4f]\n',eks_rmse1,sqrt(mean(ME1)));
  fprintf('EKS-RMSE2 = %.4f [%.4f]\n',eks_rmse2,sqrt(mean(ME2)));